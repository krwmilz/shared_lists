#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# send a valid number and verify response is ok
my $sock = new_socket();

send_msg($sock, 'new_device', "4038675309");
my ($msg_data, $length) = recv_msg($sock, 'new_device');

my $msg = check_status($msg_data, 'ok');
fail "expected response length of 46, got $length" if ($length != 46);
fail "response '$msg' not base64" unless ($msg =~ m/^[a-zA-Z0-9+\/=]+$/);

# send a bad phone number and verify error response
send_msg($sock, 'new_device', "403867530&");
($msg_data) = recv_msg($sock, 'new_device');

$msg = check_status($msg_data, 'err');
my $fail_msg = 'the sent phone number is not a number';
fail "expected failure message '$fail_msg' but got '$msg'" if ($msg ne $fail_msg);
