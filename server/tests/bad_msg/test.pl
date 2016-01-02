#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# send_msg is too sophisticated for this test
my $sock = new_socket();
print $sock pack("nn", 47837, 0);
