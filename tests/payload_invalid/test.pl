#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# send way too long message
send_msg(new_socket(), 'new_device', "longstr" x 1000);

# send message size 0 to all message types
# reuse a socket because we shouldn't get disconnected for this
my $sock = new_socket();
send_msg($sock, $_, "") for (@msg_str);
