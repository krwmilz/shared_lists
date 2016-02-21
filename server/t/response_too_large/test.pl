#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

# Test that a message greater than 65KB doesn't get sent

my $A = client->new();
$A->list_add({ name => $_, date => 0 }) for (1..600);

my $err = $A->lists_get('err');
fail_msg_ne 'response too large', $err;
