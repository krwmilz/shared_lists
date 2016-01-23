#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

# Test that large responses > 16384 bytes work as the underlying ssl layer can
# only handle that much data at a time

my $A = client->new();
for (1..500) {
	$A->list_add($_);
}

# The response to this lists_get request clocks in at ~59 KB
my $count = 0;
for my $list ($A->lists_get()) {
	$count += 1;
	fail_msg_ne "$count", $list->{name};
}
fail_num_ne 'total lists different', $count, 500;