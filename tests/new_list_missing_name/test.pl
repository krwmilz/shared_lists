#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# this test:
# - gets a new device id
# - tries to create a new list without a name

my $sock = new_socket();

send_msg($sock, 'new_device', "4038675309");
my ($msg_data, $length) = recv_msg($sock, 'new_device');

my $device_id = check_status($msg_data, 'ok');
fail "expected response length of 46, got $length" if ($length != 46);

send_msg($sock, 'new_list', "$device_id\0");
($msg_data, $length) = recv_msg($sock, 'new_list');

my $msg = check_status($msg_data, 'err');
my $msg_good = 'no list name was given';
fail "unexpected error response '$msg', expecting '$msg_good'" if ($msg ne $msg_good);
