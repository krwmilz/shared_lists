#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

my $A = client->new();

my $list = $A->list_add({ name => 'this list was made for leaving', date => 0 });
$A->list_leave($list->{num});

# verify we don't get this list back when requesting all lists
my $num_lists = scalar( @{ $A->lists_get() } );
my $num_other_lists = scalar(@{ $A->lists_get_other() });

fail_num_ne 'wrong number of lists ',$num_lists, 0;
fail_num_ne 'wrong number of other lists ', $num_other_lists, 0;
