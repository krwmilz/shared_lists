#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

# Test that large responses > 16384 bytes work as the underlying ssl layer can
# only handle that much data at a time

my $A = client->new();
$A->list_add({ name => $_, date => 0}) for (1..200);

# The response to this lists_get request clocks in at ~24 KB
my $count = 0;
for my $list (@{ $A->lists_get() }) {
	$count += 1;
	fail_msg_ne "$count", $list->{name};
}
fail_num_ne 'total lists different', $count, 200;
