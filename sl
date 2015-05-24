#!/usr/bin/perl -w

use warnings;
use strict;

use DBI;
use IO::Socket;

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
	foreign key(owner) references contacts(phone_num)
)}) or die $DBI::errstr;

# $dbh->do(qq{create table if not exists user_list(

my $sock = new IO::Socket::INET (
	LocalHost => '0.0.0.0',
	LocalPort => '5437',
	Proto => 'tcp',
	Listen => 1,
	Reuse => 1,
);

die "Could not create socket: $!\n" unless $sock;

while (1) {
	my $new_sock = $sock->accept();

	while(<$new_sock>) {
		print $_;
	}
}
close($sock);
