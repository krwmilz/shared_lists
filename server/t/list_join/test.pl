#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

my $A = client->new();
my $B = client->new();

# make A and B mutual friends
$A->friend_add($B->phnum());
$B->friend_add($A->phnum());

# A creates a new list
my $list_name = "this is a new list";
$A->list_add($list_name);
my $list_num = $A->lists(0)->{num};

# B joins A's list
my $response = $B->list_join($list_num);
my $list = $response->{list};
fail_num_ne 'list num mismatch', $list->{num}, $list_num;
fail_msg_ne 'this is a new list', $list->{name};
fail_num_ne 'date mismatch', $list->{date}, 0;
fail_num_ne 'items complete mismatch', $list->{items_complete}, 0;
fail_num_ne 'items total mismatch', $list->{items_total}, 0;
fail_num_ne 'num members mismatch', $list->{num_members}, 2;

# B requests its lists to make sure its committed to the list
($list) = $B->lists_get();

# Verify what we get from server
my $stored_list = $A->lists(0);
for ('num', 'name', 'date') {
	fail_msg_ne $stored_list->{$_}, $list->{$_};
}
