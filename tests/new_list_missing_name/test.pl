#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# this test:
# - gets a new device id
# - tries to create a new list without a name

my $sock = new_socket();
send_msg($sock, 'new_device', "4038675309");
my ($type, $device_id, $length) = recv_msg($sock);

fail "got response type '$type', expected 'new_device'" if ($type ne 'new_device');
fail "expected response length of 43, got $length" if ($length != 43);

send_msg($sock, 'new_list', "$device_id\0");
