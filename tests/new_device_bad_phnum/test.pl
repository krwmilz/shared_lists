#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# send a new device message with a bad phone number
my $sock = new_socket();
send_msg($sock, $msg_num{new_device}, "403867530&");
close($sock);
