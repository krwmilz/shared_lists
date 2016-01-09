#!/usr/bin/perl -I../
use strict;
use warnings;

use client;
use test;

my $A = client->new();
$A->device_add(rand_phnum());

$A->list_add('this list was made for leaving');
$A->list_leave($A->lists(0)->{id});

# verify we don't get this list back when requesting all lists
my @lists = $A->lists_get();
my @other_lists = $A->lists_get_other();

fail_num_ne 'wrong number of lists ', scalar @lists, 0;
fail_num_ne 'wrong number of other lists ', scalar @other_lists, 0;
