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
	foreign key(list_id) references lists(list_id),
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

my $sql = qq{insert into lists (list_id, phone_num, name, timestamp)
	values (?, ?, ?, ?)};
my $new_list_sth = $dbh->prepare($sql);

print "info: ready for connections\n";
while (my ($new_sock, $bin_addr) = $sock->accept()) {

	my ($err, $addr, $port) = getnameinfo($bin_addr, NI_NUMERICHOST | NI_NUMERICSERV);
	print "warn: getnameinfo() failed: $err\n" if ($err);
	print "info: new connection from $addr:$port\n";

	read $new_sock, my $msg_type, 1;

	if ($msg_type == 1) {
		my $hdr = "new list";
		print "info: received msg type = new list\n";

		read $new_sock, my $new_list_size, 2;
		if (!looks_like_number($new_list_size)) {
			print "warn: $hdr: $new_list_size is not a number, skipping\n";
			close($new_sock);
			next;
		}
		# we know this is safe
		$new_list_size = int($new_list_size);

		read($new_sock, my $new_list, $new_list_size);
		my ($phone_num, $name) = split("\0", $new_list);

		unless ($name && $name ne "") {
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
		print "info: $hdr: name = $name\n";

		my $time = time;
		my $list_id = sha256_hex($new_list . $time);
		print "info: $hdr: list id = $list_id\n";

		$new_list_sth->execute($list_id, $phone_num, $name, $time);

		print $new_sock $list_id;
	}
	else {
		print "info: bad message type $msg_type\n";
	}

	close($new_sock);
}
$dbh->disconnect();
close($sock);
