#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# send an invalid message type
my $sock = new_socket();
print $sock pack("nnn", 101, 0, 0);
