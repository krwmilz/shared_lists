#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

# Test that a message greater than 65KB doesn't get sent

my $A = client->new();
for (1..600) {
	$A->list_add($_);
}

$A->lists_get('err');
fail_msg_ne 'response too large', $A->get_error();
