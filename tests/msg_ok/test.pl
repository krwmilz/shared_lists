#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

my $sock = new_socket();

send_msg($sock, 'new_device', "4038675309\0unix");
my ($msg_data, $length) = recv_msg($sock, 'new_device');

my $device_id = check_status($msg_data, 'ok');

send_msg($sock, 'ok', $device_id);
($msg_data, $length) = recv_msg($sock, 'ok');

check_status($msg_data, 'ok');
fail "expected response size 3, got $length" if ($length != 3);
