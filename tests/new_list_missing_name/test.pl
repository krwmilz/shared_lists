#!/usr/bin/perl -Itests/

use strict;
use warnings;

use testlib;

# this test:
# - gets a new device id
# - tries to create a new list without a name

my $sock = new_socket();
send_msg($sock, 0, "4038675309");
my ($type, $device_id, $length) = recv_msg($sock);

fail "got response type $type, expected 0" if ($type != 0);
fail "expected response length of 43, got $length" if ($length != 43);

send_msg($sock, 1, "$device_id\0");
