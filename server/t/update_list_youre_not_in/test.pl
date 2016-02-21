#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

# Create A and B
my $A = client->new();
my $B = client->new();

# A adds a new list
my $list = $A->list_add({ name => 'this is a new list for a', date => 0 });

# B tries to update A's list without joining it first
my $request = { num => $list->{num}, name => 'some new name', date => 1 };
my $err = $B->list_update($request, 'err');
fail_msg_ne 'client tried to update a list it was not in', $err;
