#!/usr/bin/perl -I..

use strict;
use warnings;

use testlib;

# this test:
# - gets a new device id
# - tries to create a new list with and invalid device id

my $sock = new_socket();
send_msg($sock, 1, "a\0some list over here");
