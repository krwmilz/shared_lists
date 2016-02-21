#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

my $A = client->new();
my $B = client->new();

# A and B are mutual friends
$A->friend_add($B->phnum());
$B->friend_add($A->phnum());

# A creates 2 lists
my $As_first_list = $A->list_add({ name => "this is a's first list", date => 0 });
$A->list_add({ name => "this is a's second list", date => 0 });
# B creates 1 list
$B->list_add({ name => "this is b's first list", date => 0});

# B joins A's first list
$B->list_join($As_first_list->{num});

# A deletes B's friendship
$A->friend_delete($B->phnum());

# Check that:
# - A and B are both in A's first list
# - B can't see A's other list
# - A can't see B's other list
my $A_other_lists = scalar @{ $A->lists_get_other() };
my $B_other_lists = scalar @{ $B->lists_get_other() };
fail "expected A to have 0 other lists" if ($A_other_lists != 0);
fail "expected B to have 0 other lists" if ($B_other_lists != 0);

my $A_num_lists = scalar @{ $A->lists_get() };
my $B_num_lists = scalar @{ $B->lists_get() };
fail "expected A to have 2 lists" if ($A_num_lists != 2);
fail "expected B to have 2 lists" if ($B_num_lists != 2);
