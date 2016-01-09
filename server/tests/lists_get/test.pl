#!/usr/bin/perl -I../
use strict;
use warnings;

use client;
use test;

# this test:
# - gets a new device id
# - creates some new lists
# - requests all lists
# - checks that what's received is what was sent

my $A = client->new();
$A->device_add(my $phnum = rand_phnum());

for ('new list 1', 'new list 2', 'new list 3') {
	$A->list_add($_);
}

my @client_lists = $A->lists_all();
my @lists = $A->lists_get();
my $i = 0;
my $num_lists = 0;
for (@lists) {
	my $list = $A->lists($i++);

	#fail_msg_ne $_->{'id'}, $list->{'id'};
	fail_num_ne 'wrong number of members', $_->{num_members}, $list->{num_members};
	fail_msg_ne $phnum, $_->{members}->[0];
	#fail_msg_ne $_->{'name'}, $list->{name};

	$num_lists++;
}
fail_num_ne 'wrong number of lists', $num_lists, 3;
