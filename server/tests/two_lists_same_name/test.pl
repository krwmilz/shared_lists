#!/usr/bin/perl -I../
use strict;
use warnings;

use client;
use test;

my $A = client->new();
$A->device_add(rand_phnum());

# check that adding the same list twice works
my $name = 'some list thats going to be added twice';
$A->list_add($name);
$A->list_add($name);

my @lists = $A->lists_get();
# XXX: add validation this gives back 2 independent lists
