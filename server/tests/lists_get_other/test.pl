#!/usr/bin/perl -I../
use strict;
use warnings;

use client;
use test;

# this test:
# - gets two new device id's
# - the two devices add each other mutually
# - device 1 creates a new list
# - then verify that device 2 can see it

my $A = client->new();
my $B = client->new();

$A->device_add(rand_phnum());
$B->device_add(rand_phnum());

$A->friend_add($B->phnum());
$B->friend_add($A->phnum());

$A->list_add('this is a new list that B can see');
my $as_list = $A->lists(0);

my @other_lists = $B->lists_get_other();
fail_msg_ne $other_lists[0]->{name}, $as_list->{'name'};
fail_msg_ne $other_lists[0]->{id}, $as_list->{'id'};
fail_num_ne 'wrong number of list members', $other_lists[0]->{num_members}, 1;
fail_msg_ne $other_lists[0]->{members}->[0], $A->phnum();
fail_num_ne 'wrong number of other lists', scalar(@other_lists), 1;
