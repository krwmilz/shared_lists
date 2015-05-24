#!/usr/bin/perl -w

use warnings
use strict

use DBI;

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

$dbh->do(qq{create table if not exists user_list(
