#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

my $A = client->new();

# Try and update a list that doesn't exist
$A->list_update(123456, 'some name', 0, 'err');
fail_msg_ne 'the client sent an unknown list number', $A->get_error();

# Make sure a normal list_update works
$A->list_add('this is a new list');
$A->list_update($A->lists(0)->{id}, 'this is an updated name', 54345);

my @lists = $A->lists_get();
fail_msg_ne $lists[0]->{name}, 'this is an updated name';
