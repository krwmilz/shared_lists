#!/usr/bin/perl -Itests

use strict;
use warnings;

use MsgTypes;
use testlib;

# send a new device message with a bad phone number
my $sock = new_socket();
send_msg($sock, $msgs{new_device}, "403867530&");
close($sock);
