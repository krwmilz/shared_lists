#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

my $sock = new_socket();
send_msg($sock, 'new_device', "");
close $sock;
