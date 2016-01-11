#!/usr/bin/perl -I../
use strict;
use warnings;

use client;
use test;

my $A = client->new();
my $B = client->new();

# make A and B mutual friends
$A->friend_add($B->phnum());
$B->friend_add($A->phnum());

# A creates a new list
my $list_name = "this is a new list";
$A->list_add($list_name);

# B joins A's list
$B->list_join($A->lists(0)->{'id'});

# B requests its lists to make sure its committed to the list
my @lists = $B->lists_get();

# fail "request list id mismatch: '$id' ne '$list_id'" if ($id ne $list_id);
# fail "unexpected name '$name', expected '$list_name'" if ($name ne $list_name);
# fail "expected 2 list members, got ". @members if (@members != 2);
