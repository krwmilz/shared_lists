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
$A->list_add("this is a's first list");
$A->list_add("this is a's second list");
# B creates 1 list
$B->list_add("this is b's first list");

# B joins one of A's list
$B->list_join($A->lists(0)->{'id'});

# A deletes B's friendship
$A->friend_delete($B->phnum());

# Check that:
# - A and B are both in A's first list
# - B can't see A's other list
# - A can't see B's other list
fail "expected A to have 0 other lists" if ($A->lists_get_other() != 0);
fail "expected B to have 0 other lists" if ($B->lists_get_other() != 0);

fail "expected A to have 2 lists" if ($A->lists_get() != 2);
fail "expected B to have 2 lists" if ($B->lists_get() != 2);
