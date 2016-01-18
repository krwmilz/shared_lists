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

# B joins A's list
$B->list_join($A->lists(0)->{num});

# B requests its lists to make sure its committed to the list
my ($list) = $B->lists_get();

# Verify what we get from server
my $stored_list = $A->lists(0);
for ('num', 'name', 'date') {
	fail_msg_ne $stored_list->{$_}, $list->{$_};
}
