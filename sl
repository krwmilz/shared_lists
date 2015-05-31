#!/usr/bin/perl -w

use warnings;
use strict;

use BSD::arc4random qw(:all);
use DBI;
use Digest::SHA qw(sha256_base64);
use IO::Socket qw(getnameinfo NI_NUMERICHOST NI_NUMERICSERV);
use Scalar::Util qw(looks_like_number);
use Socket;

my $dbh = DBI->connect(
	"dbi:SQLite:dbname=db",
	"",
	"",
	{ RaiseError => 1 }
) or die $DBI::errstr;

$dbh->do(qq{create table if not exists devices(
		token text not null primary key,
		phone_num int not null,
		first_seen int not null)
}) or die $DBI::errstr;

$dbh->do(qq{create table if not exists list_data(
	list_id int not null,
	position int not null,
	text text not null,
	status int not null default 0,
	owner int not null,
	last_updated int not null,
	primary key(list_id, position),
	foreign key(list_id) references lists(list_id),
	foreign key(owner) references devices(phone_num))
}) or die $DBI::errstr;

$dbh->do(qq{create table if not exists lists(
	list_id int not null primary key,
	device_id text not null,
	name text not null,
	first_created int not null,
	last_updated int not null,
	foreign key(device_id) references devices(token))
}) or die $DBI::errstr;

$dbh->do(qq{create table if not exists friends_map(
	user int not null,
	friend int not null,
	primary key(user, friend),
	foreign key(user) references devices(phone_num))
}) or die $DBI::errstr;

$dbh->do(qq{create table if not exists mutual_friends(
	user int not null,
	mutual_friend int not null,
	primary key(user, mutual_friend),
	foreign key(user) references devices(phone_num))
}) or die $DBI::errstr;

my $sock = new IO::Socket::INET (
	LocalHost => '0.0.0.0',
	LocalPort => '5437',
	Proto => 'tcp',
	Listen => 1,
	Reuse => 1,
);

die "Could not create socket: $!\n" unless $sock;

my $sql = qq{insert into lists (list_id, device_id, name, first_created, last_updated)
	values (?, ?, ?, ?, ?)};
my $new_list_sth = $dbh->prepare($sql);

$sql = qq{insert into devices (token, phone_num, first_seen) values (?, ?, ?)};
my $new_device_sth = $dbh->prepare($sql);

$sql = qq{insert into friends_map (user, friend) values (?, ?)};
my $friends_map_sth = $dbh->prepare($sql);

$sql = qq{select * from devices where phone_num = ?};
my $ph_num_exists_sth = $dbh->prepare($sql);

$sql = qq{select * from devices where token = ?};
my $device_id_exists_sth = $dbh->prepare($sql);

print "info: ready for connections\n";
while (my ($new_sock, $bin_addr) = $sock->accept()) {

	# don't try and resolve ip address or port
	my ($err, $addr, $port) = getnameinfo($bin_addr, NI_NUMERICHOST | NI_NUMERICSERV);
	print "warn: getnameinfo() failed: $err\n" if ($err);
	print "info: $addr: new connection on port $port\n";

	# put socket into binary mode
	binmode($new_sock);

	# read and unpack message type
	my $bread = read $new_sock, my $raw_msg_type, 2;
	my ($msg_type) = unpack("n", $raw_msg_type);

	# validate message type
	if (!defined $msg_type) {
		print "warn: $addr: error unpacking msg type\n";
		close $new_sock;
		next;
	}
	if ($msg_type > 5) {
		print "warn: $addr: unknown message type " . sprintf "0x%x\n", $msg_type;
		close $new_sock;
		next;
	}
	print "info: $addr: message type $msg_type\n";

	# read and unpack message size
	read($new_sock, my $raw_msg_size, 2);
	my ($msg_size) = unpack("n", $raw_msg_size);

	# validate message size
	if ($msg_size == 0) {
		print "warn: $addr: size zero message\n";
		close($new_sock);
		next;
	}
	if ($msg_size > 1024) {
		print "warn: $addr: message too large: $msg_size\n";
		close($new_sock);
		next;
	}
	print "info: $addr: message size = $msg_size\n";

	# read message
	read($new_sock, my $msg, $msg_size);

	if ($msg_type == 1) {
		# new list

		# expecting two fields delimited by null
		my ($device_id, $list_name) = split("\0", $msg);

		# validate input
		if (device_id_invalid($device_id, $addr)) {
			close $new_sock;
			next;
		}
		unless ($list_name && $list_name ne "") {
			print "warn: $addr: name missing or empty\n";
			close($new_sock);
			next;
		}

		print "info: $addr: device id = $device_id\n";
		print "info: $addr: list name = $list_name\n";

		my $time = time;
		my $list_id = sha256_base64($msg . $time);
		print "info: $addr: list id = $list_id\n";

		$new_list_sth->execute($list_id, $device_id, $list_name, $time, $time);

		print $new_sock $list_id;
	}
	elsif ($msg_type == 2) {
		# update friend map

		# device id followed by 0 or more friends numbers
		my ($device_id, @friends) = split("\0", $msg);

		if (device_id_invalid($device_id, $addr)) {
			close $new_sock;
			next;
		}
		print "info: $addr: device $device_id, " . @friends . " friends\n";

		for (@friends) {
			unless (looks_like_number($_)) {
				print "warn: bad friends number $_\n";
				next;
			}
			$friends_map_sth->execute($device_id, $_);
			print "info: $addr: added friend $_\n";
		}
	}
	elsif ($msg_type == 3) {
		# new device

		# single field
		my $ph_num = $msg;

		if (!looks_like_number($ph_num)) {
			print "warn: $addr: device phone number $ph_num invalid\n";
			close $new_sock;
			next;
		}
		if ($dbh->selectrow_array($ph_num_exists_sth, undef, $ph_num)) {
			print "warn: $addr: phone number $ph_num already exists\n";
			close $new_sock;
			next;
		}

		# make a new device id, the client will supply this on all
		# further communication
		my $token = sha256_base64(arc4random_bytes(32));

		print $new_sock $token;
		$new_device_sth->execute($token, $ph_num, time);
	}

	close($new_sock);
}
$dbh->disconnect();
close($sock);

sub device_id_invalid
{
	my $device_id = shift;
	my $addr = shift;

	# validate this at least looks like base64
	unless ($device_id =~ m/^[a-zA-Z0-9=]+$/) {
		print "warn: $addr: device id $device_id invalid\n";
		return 1;
	}

	# make sure we know about this device id
	unless ($dbh->selectrow_array($device_id_exists_sth, undef, $device_id)) {
		print "warn: $addr: unknown device $device_id\n";
		return 1;
	}

	return 0;
}
