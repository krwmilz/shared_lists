#!/usr/bin/perl -I../
use strict;
use warnings;

use client;
use test;

# test list reference counting to make sure they stay alive when needed
my $A = client->new();
my $B = client->new();

# A creates a new list
$A->list_add('this list will belong to B soon enough');
my $list_id = $A->lists(0)->{'id'};

# XXX: missing steps
# - A and B become mutual friends
# - B requests his other lists
# - B joins A's list

# B joins A's list, A leaves its own list
$B->list_join($list_id);
$A->list_leave($list_id);

# B verifies its still in the list
my @lists = $B->lists_get();
fail_num_ne 'wrong number of lists ', scalar(@lists), 1;

# B also leaves the list
$B->list_leave($list_id);
