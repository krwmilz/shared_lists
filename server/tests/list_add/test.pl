#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;
use Scalar::Util qw(looks_like_number);

my $A = client->new();

# make sure normal list_add works
$A->list_add(my $name = 'this is a new list');
my $list = $A->lists(0);

fail "list num isn't numeric" unless (looks_like_number($list->{id}));
fail_msg_ne $name, $list->{name};
fail_num_ne "wrong number of members", $list->{num_members}, 1;
fail_msg_ne $list->{members}->[0], $A->phnum();

# verify a new_list request with an empty list name succeeds
$A->list_add('');

fail_num_ne "wrong number of lists", $A->num_lists(), 2;
