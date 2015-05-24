#!/usr/bin/perl -w

use warnings;
use strict;

use DBI;
use IO::Socket;
use Scalar::Util qw(looks_like_number);

my $dbh = DBI->connect(
	"dbi:SQLite:dbname=db",
	"",
	"",
	{ RaiseError => 1 }
) or die $DBI::errstr;

$dbh->do(qq{create table if not exists contacts(
		phone_num int not null primary key,
		name text not null)
}) or die $DBI::errstr;

$dbh->do(qq{create table if not exists list_data(
	list_id int not null,
	position int not null,
	text text not null,
	status int not null default 0,
	owner int not null,
	primary key(list_id, position),
	foreign key(owner) references contacts(phone_num))
}) or die $DBI::errstr;

$dbh->do(qq{create table if not exists lists(
	list_id int not null primary key,
	phone_num int not null,
	name text not null,
	timestamp int not null)
}) or die $DBI::errstr;

my $sock = new IO::Socket::INET (
	LocalHost => '0.0.0.0',
	LocalPort => '5437',
	Proto => 'tcp',
	Listen => 1,
	Reuse => 1,
);

die "Could not create socket: $!\n" unless $sock;

srand;

my $sql = qq{insert into lists (list_id, phone_num, name, timestamp)
	values (?, ?, ?, ?)};
my $new_list_sth = $dbh->prepare($sql);

while (my $new_sock = $sock->accept()) {

	read $new_sock, my $msg_type, 1;
	if ($msg_type == 1) {
		# new list

		print "msg_type is new_list\n";
		read $new_sock, my $new_list_size, 2;

		if (!looks_like_number($new_list_size)) {
			print "warn: $new_list_size is not a number, skipping\n";
			next;
		}
		# we know this is safe
		$new_list_size = int($new_list_size);

		print "info: message size = $new_list_size\n";
		read $new_sock, my $new_list, $new_list_size;

		print "info: raw message: $new_list\n";
		my ($phone_num, $name) = split("\0", $new_list);

		unless ($name && $name ne "") {
			print "info: name missing or empty, skipping\n";
			next;
		}
		unless ($phone_num && $phone_num ne "") {
			print "info: phone number missing, skipping\n";
			next;
		}

		if (!looks_like_number($phone_num)) {
			print "warn: $phone_num is not a number, skipping\n";
			next;
		}
		print "info: new list: phone number = $phone_num\n";
		print "info: new list: name = $name\n";
		my $list_id = rand;
		print "info: list id = $list_id";

		$new_list_sth->execute($list_id, $phone_num, $name, time);
	}
	else {
		print "info: bad message type $msg_type\n";
	}

	close($new_sock);
}
$dbh->disconnect();
close($sock);
