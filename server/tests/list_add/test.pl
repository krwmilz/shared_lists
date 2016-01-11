#!/usr/bin/perl -I../
use strict;
use warnings;

use client;
use test;
use Data::Dumper;

my $A = client->new();

# make sure normal list_add works
$A->list_add(my $name = 'this is a new list');
my $list = $A->lists(0);

fail_num_ne "bad id length", length($list->{id}), 43;
fail_msg_ne $name, $list->{name};
fail_num_ne "wrong number of members", $list->{num_members}, 1;
fail_msg_ne $list->{members}->[0], $A->phnum();

# verify a new_list request with an empty list name succeeds
$A->list_add('');

fail_num_ne "wrong number of lists", $A->num_lists(), 2;
