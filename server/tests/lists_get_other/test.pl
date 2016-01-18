#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

# Create A and B
my $A = client->new();
my $B = client->new();

# A and B become mutual friends
$A->friend_add($B->phnum());
$B->friend_add($A->phnum());

# A adds a new list
$A->list_add('this is a new list that B can see');
my $as_list = $A->lists(0);

# Check that B can see As list
my @other_lists = $B->lists_get_other();
fail_msg_ne $other_lists[0]->{name}, $as_list->{'name'};
fail_msg_ne $other_lists[0]->{num}, $as_list->{'num'};
fail_num_ne 'wrong number of list members', $other_lists[0]->{num_members}, 1;
fail_msg_ne $other_lists[0]->{members}->[0], $A->phnum();
fail_num_ne 'wrong number of other lists', scalar(@other_lists), 1;
