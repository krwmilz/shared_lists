#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

my $A = client->new();

# Create 3 new lists
my @stored_lists;
for ('new list 1', 'new list 2', 'new list 3') {
	push @stored_lists, $A->list_add({ name => $_, date => 0 });
}

my $i = 0;
# Verify the information from lists_get matches what we know is true
for my $list (@{ $A->lists_get() }) {
	my $num = $list->{num};
	my $stored_list = $stored_lists[$i];

	fail_msg_ne $list->{num}, $stored_list->{num};
	fail_num_ne 'wrong number of members', $list->{num_members}, $stored_list->{num_members};
	fail_msg_ne $A->phnum, $list->{members}->[0];
	fail_msg_ne $list->{name}, $stored_list->{name};
	fail_num_ne 'date not the same', $list->{date}, $stored_list->{date};
	fail_num_ne 'items total not the same', $list->{items_total}, 0;
	fail_num_ne 'items complete not the same', $list->{items_complete}, 0;
	$i++;
}
fail_num_ne 'wrong number of lists', $i, 3;
