#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;
use Scalar::Util qw(looks_like_number);

my $A = client->new();

# make sure normal list_add works
my $name = 'this is a new list';
my $list = $A->list_add({ name => $name, date => 0 });

fail "list num isn't numeric" unless (looks_like_number($list->{num}));
fail_msg_ne $name, $list->{name};
fail_num_ne "wrong number of members", $list->{num_members}, 1;
fail_msg_ne $list->{members}->[0], $A->phnum();

# verify a new_list request with an empty list name succeeds
$A->list_add({ name => '', date => 0 });

my $num_lists = scalar( @{ $A->lists_get() } );
fail_num_ne "wrong number of lists", $num_lists, 2;
