#!/usr/bin/perl -w

use warnings;
use strict;

use BSD::arc4random qw(:all);
use DBI;
use Digest::SHA qw(sha256_base64);
use Getopt::Std;
use IO::Socket qw(getnameinfo NI_NUMERICHOST NI_NUMERICSERV);
use Scalar::Util qw(looks_like_number);
use Socket;

my %args;
getopts("p:", \%args);

my $dbh = DBI->connect(
	"dbi:SQLite:dbname=db",
	"",
	"",
	{ RaiseError => 1 }
) or die $DBI::errstr;

$dbh->do(qq{create table if not exists devices(
		token text not null primary key,
		phone_num int not null,
		type text,
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
	name text not null,
	first_created int not null,
	last_updated int not null)
}) or die $DBI::errstr;

$dbh->do(qq{create table if not exists list_members(
	list_id int not null primary key,
	device_id text not null,
	joined_date int not null,
	primary key(list_id, device_id),
	foreign key(list_id) references lists(list_id),
	foreign key(device_id) references devices(token))
}) or die $DBI::errstr;

$dbh->do(qq{create table if not exists friends_map(
	device_id text not null,
	friend int not null,
	primary key(device_id, friend),
	foreign key(device_id) references devices(token))
}) or die $DBI::errstr;

$dbh->do(qq{create table if not exists mutual_friends(
	device_id text not null,
	mutual_friend text not null,
	primary key(device_id, mutual_friend),
	foreign key(device_id) references devices(device_id))
}) or die $DBI::errstr;

my $sock = new IO::Socket::INET (
	LocalHost => '0.0.0.0',
	LocalPort => $args{p} || '5437',
	Proto => 'tcp',
	Listen => 1,
	Reuse => 1,
);

die "Could not create socket: $!\n" unless $sock;
my $local_addr_port = inet_ntoa($sock->sockaddr) . ":" .$sock->sockport();

my $sql = qq{insert into lists (list_id, name, first_created, last_updated)
	values (?, ?, ?, ?)};
my $new_list_sth = $dbh->prepare($sql);

$sql = qq{insert into devices (token, phone_num, first_seen) values (?, ?, ?)};
my $new_device_sth = $dbh->prepare($sql);

$sql = qq{insert into friends_map (device_id, friend) values (?, ?)};
my $friends_map_sth = $dbh->prepare($sql);

$sql = qq{select friend from friends_map where device_id = ?};
my $friends_map_select_sth = $dbh->prepare($sql);

$sql = qq{delete from friends_map where device_id = ?};
my $friends_map_delete_sth = $dbh->prepare($sql);

$sql = qq{delete from mutual_friends where device_id = ? or mutual_friend = ?};
my $mutual_friends_delete_sth = $dbh->prepare($sql);

$sql = qq{select * from devices where phone_num = ?};
my $ph_num_exists_sth = $dbh->prepare($sql);

$sql = qq{select * from devices where token = ?};
my $device_id_exists_sth = $dbh->prepare($sql);

$sql = qq{select lists.list_id, lists.name from lists, list_members where
	lists.list_id = list_members.list_id and device_id = ?};
my $get_lists_sth = $dbh->prepare($sql);

$sql = qq{select device_id from list_members where list_id = ?};
my $get_list_members_sth = $dbh->prepare($sql);

$sql = qq{insert into list_members (list_id, device_id, joined_date) values (?, ?, ?)};
my $new_list_member_sth = $dbh->prepare($sql);


print "info: ready for connections on $local_addr_port\n";
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
	if (!defined $msg_size) {
		print "warn: $addr: error unpacking msg type\n";
		close $new_sock;
		next;
	}
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

	if ($msg_type == 0) {
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
		# XXX: need to check the db to make sure this isn't duplicate
		my $token = sha256_base64(arc4random_bytes(32));

		# token length 43 = 0x2b
		print $new_sock "\x00\x00\x2b\x00";
		print $new_sock $token;
		$new_device_sth->execute($token, $ph_num, time);
		print "info: $addr: added new device $ph_num:$token\n";
	}
	elsif ($msg_type == 1) {
		# new list

		# expecting two fields delimited by null
		my ($device_id, $list_name) = split("\0", $msg);

		# validate input
		if (device_id_invalid($device_id, $addr)) {
			close $new_sock;
			next;
		}
		unless ($list_name) {
			print "warn: $addr: list name missing\n";
			close($new_sock);
			next;
		}

		print "info: $addr: adding new list: $list_name\n";
		print "info: $addr: adding first list member $device_id\n";

		my $time = time;
		my $list_id = sha256_base64($msg . $time);
		print "info: $addr: list id = $list_id\n";

		# add new list with single list member
		$new_list_sth->execute($list_id, $list_name, $time, $time);
		$new_list_member_sth->execute($list_id, $device_id, $time);

		print $new_sock pack("n", 1);
		print $new_sock pack("n", length($list_id));
		print $new_sock $list_id;
	}
	elsif ($msg_type == 2) {
		# update friend map, note this is meant to be a wholesale update
		# of the friends that are associated with a given device id

		# device id followed by 0 or more friends numbers
		my ($device_id, @friends) = split("\0", $msg);

		if (device_id_invalid($device_id, $addr)) {
			close $new_sock;
			next;
		}
		print "info: $addr: device $device_id, " . @friends . " friends\n";

		# delete all friends, remove mutual friend references
		$friends_map_delete_sth->execute($device_id);
		$mutual_friends_delete_sth->execute($device_id, $device_id);

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
		# get both lists the device is in, and lists it can see

		# check if the device id is valid
		if (device_id_invalid($msg, $addr)) {
			# XXX: i don't think $msg is null terminated
			print "warn: device id $msg invalid\n";
			close $new_sock;
			next;
		}

		# keep the message types synced
		my $out = pack("n", 3);;

		print "info: gathering lists for $msg\n";

		my @direct_lists;
		# first get all lists this device id is a direct member of
		$get_lists_sth->execute($msg);
		while (my ($list_id, $list_name) = $get_lists_sth->fetchrow_array()) {
			print "info: $addr: found list '$list_name' : $list_id\n";

			# get all members of this list
			my @list_members;
			$get_list_members_sth->execute($list_id);
			while (my ($member_device_id) = $get_list_members_sth->execute($list_id)) {
				push @list_members, $member_device_id;
				print "info: $addr: direct list: found member $member_device_id\n";
			}

			push @direct_lists, "$list_name:$list_id:" . join(":", @list_members);
		}
		$out += join("\0", @direct_lists);

		# separator between direct lists
		$out += "\0\0";

		my @indirect_lists;
		# now calculate which lists this device id should see
		$friend_map_select_sth->execute($msg);
		while (my ($friend) = $friend_map_select_sth->fetchrow_array()) {
			print "info: $addr: found friend $friend";

			# get all of my friends lists
			$get_lists_sth->execute($friend);
			while (my ($list_id, $list_name) =
				$get_lists_sth->fetchrow_array()) {

				push @indirect_lists
		}


		# my $temp = join("\0", @temp);
		# $out .= length $temp;
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
	unless ($device_id =~ m/^[a-zA-Z0-9+\/=]+$/) {
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
