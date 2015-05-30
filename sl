#!/usr/bin/perl -w

use warnings;
use strict;

use DBI;
use Digest::SHA qw(sha256_hex);
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
		phone_num int not null primary key,
		name text not null,
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
	phone_num int not null,
	name text not null,
	first_created int not null,
	last_updated int not null)
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

my $sql = qq{insert into lists (list_id, phone_num, name, first_created, last_updated)
	values (?, ?, ?, ?, ?)};
my $new_list_sth = $dbh->prepare($sql);

print "info: ready for connections\n";
while (my ($new_sock, $bin_addr) = $sock->accept()) {

	my ($err, $addr, $port) = getnameinfo($bin_addr, NI_NUMERICHOST | NI_NUMERICSERV);
	print "warn: getnameinfo() failed: $err\n" if ($err);
	print "info: new connection from $addr:$port\n";
	my $hdr = $addr;

	binmode($new_sock);

	read $new_sock, my $msg_type, 1;

	my $msg_size_size = undef;
	$msg_size_size = 1 if ($msg_type == 1);
	$msg_size_size = 2 if ($msg_type == 2);
	$msg_size_size = 1 if ($msg_type == 3);
	$msg_size_size = 1 if ($msg_type == 4);

	unless (defined $msg_size_size) {
		print "warn: unknown msg type " .  printf "%x\n", $msg_type;
		close $new_sock;
		next;
	}
	print "info: msg size size = $msg_size_size\n";
	my $ascii_msg_type = sprintf("%x", $msg_type);
	print "info: received msg type $ascii_msg_type\n";

	read($new_sock, my $msg_size, $msg_size_size);
	if ($msg_size == 0) {
		print "warn: empty message received\n";
	}
	print "info: msg size = $msg_size\n";

	read($new_sock, my $msg, $msg_size);

	if ($msg_type == 1) {
		my ($phone_num, $list_name) = split("\0", $msg);

		unless ($list_name && $list_name ne "") {
			print "warn: $hdr: name missing or empty, skipping\n";
			close($new_sock);
			next;
		}
		unless ($phone_num && $phone_num ne "") {
			print "warn: $hdr: phone number missing, skipping\n";
			close($new_sock);
			next;
		}

		if (!looks_like_number($phone_num)) {
			print "warn: $hdr: $phone_num is not a number, skipping\n";
			close($new_sock);
			next;
		}
		print "info: $hdr: phone number = $phone_num\n";
		print "info: $hdr: list name = $list_name\n";

		my $time = time;
		my $list_id = sha256_hex($msg . $time);
		print "info: $hdr: list id = $list_id\n";

		$new_list_sth->execute($list_id, $phone_num, $list_name, $time, $time);

		print $new_sock $list_id;
	}
	elsif ($msg_type == 2) {
		# update friend visibility map
		my ($device_ph_num, @friends) = split("\0", $msg);

		if (!looks_like_number($device_ph_num)) {
			print "warn: device phone number $device_ph_num invalid, skipping\n";
			close $new_sock;
			next;
		}

		print "info: device $device_ph_num, " . @friends . " friends\n";
	}
	elsif ($msg_type == 3) {
		# new device
		my ($device_ph_num, $name) = split("\0", $msg);
	}

	close($new_sock);
}
$dbh->disconnect();
close($sock);
