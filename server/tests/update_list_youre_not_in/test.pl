#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

# Create A and B
my $A = client->new();
my $B = client->new();

# A adds a new list
$A->list_add('this is a new list for a');
my $list_num = $A->lists(0)->{num};

# B tries to update A's list without joining it first
$B->list_update({ num => $list_num, name => 'some new name', date => 1 }, 'err');
fail_msg_ne 'client tried to update a list it was not in', $B->get_error();
