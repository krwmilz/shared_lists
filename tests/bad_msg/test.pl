#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

my $sock = new_socket();
# send_msg is too sophisticated for this test
print $sock pack("nn", 47837, 0);
close $sock;
