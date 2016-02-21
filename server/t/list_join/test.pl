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
my $As_list = $A->list_add({ name => $list_name, date => 0 });

# B joins A's list
my $list = $B->list_join($As_list->{num});
fail_num_ne 'list num mismatch', $list->{num}, $As_list->{num};
fail_msg_ne 'this is a new list', $list->{name};
fail_num_ne 'date mismatch', $list->{date}, 0;
fail_num_ne 'items complete mismatch', $list->{items_complete}, 0;
fail_num_ne 'items total mismatch', $list->{items_total}, 0;
fail_num_ne 'num members mismatch', $list->{num_members}, 2;

# B requests its lists to make sure its committed to the list
($list) = @{ $B->lists_get() };

# Verify what we get from server
for ('num', 'name', 'date') {
	fail_msg_ne $As_list->{$_}, $list->{$_};
}
