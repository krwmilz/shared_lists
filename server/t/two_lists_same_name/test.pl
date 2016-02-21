#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

my $A = client->new();

# check that adding the same list twice works
my $name = 'some list thats going to be added twice';
$A->list_add({ name => $name, date => 0 });
$A->list_add({ name => $name, date => 0 });

my $num_lists = scalar(@{ $A->lists_get() });
fail_num_ne "wrong number of lists", $num_lists, 2;
# XXX: add validation this gives back 2 independent lists
