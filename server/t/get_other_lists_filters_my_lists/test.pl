#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

# Check that when your mutual friends are in your own lists that you don't get
# your own lists back when doing a lists_get_other request

# Create A and B
my $A = client->new();
my $B = client->new();

# B adds a new list
$B->list_add({ name => 'bs new list', date => 0 });

# A and B become mutual friends
$A->friend_add($B->phnum());
$B->friend_add($A->phnum());

# A adds a new list, B joins A's new list
my $list = $A->list_add({ name => 'as new list', date => 0 });
$B->list_join($list->{num});

# A should only see B's list that it never joined
my $other = $A->lists_get_other();
fail_num_ne 'wrong number of other lists ', scalar(@$other), 1;
