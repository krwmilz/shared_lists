#!/usr/bin/perl -I../
use strict;
use warnings;

use test;
use client;

# this test makes sure that when 2 friends of yours are in the same list that
# your not in, that the list doesn't show up twice in your list_get_other
# request.

my $A = client->new();
my $B = client->new();
my $C = client->new();

# A and B are mutual friends
$A->friend_add($B->phnum());
$B->friend_add($A->phnum());

# A and C are also mutual friends
$A->friend_add($C->phnum());
$C->friend_add($A->phnum());

# B and C need to be in the same list
$B->list_add('this is Bs new list');
$C->list_join($B->lists(0)->{'id'});

# A makes sure he got a single list
my @other = $A->lists_get_other();
fail_num_ne 'wrong number of list members', $other[0]->{num_members}, 2;
fail_msg_ne $other[0]->{id}, $B->lists(0)->{'id'};
fail_num_ne 'wrong number of lists', scalar(@other), 1;
fail "A found unexpectedly" if (grep {$_ eq $A->phnum()} @{$other[0]->{members}});
fail "member B not found" unless (grep {$_ eq $B->phnum()} @{$other[0]->{members}});
fail "member C not found" unless (grep {$_ eq $C->phnum()} @{$other[0]->{members}});
