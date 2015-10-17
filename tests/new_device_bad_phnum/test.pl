#!/usr/bin/perl -I..

use strict;
use warnings;

use testlib;

# send a new device message with a bad phone number
my $sock = new_socket();
send_msg($sock, 0, "403867530&");
close($sock);
