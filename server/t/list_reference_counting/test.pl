#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

# Test list reference counting to make sure they stay alive when needed
my $A = client->new();
my $B = client->new();

# A creates a new list
my $list = $A->list_add({ name => 'this list will belong to B soon enough', date => 0 });

# XXX: missing steps
# - A and B become mutual friends
# - B requests his other lists
# - B joins A's list

# B joins A's list, A leaves its own list
$B->list_join($list->{num});
$A->list_leave($list->{num});

# B verifies its still in the list
my $num_lists = scalar(@{ $B->lists_get() });
fail_num_ne 'wrong number of lists ', $num_lists, 1;

# B also leaves the list
$B->list_leave($list->{num});
