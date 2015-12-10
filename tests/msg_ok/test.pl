#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

my $sock = new_socket();

send_msg($sock, 'new_device', "4038675309");
my (undef, $device_id) = recv_msg($sock);

send_msg($sock, 'ok', $device_id);
my ($type, $response, $length) = recv_msg($sock);

fail "expected msg type 'ok', got '$type'" if ($type ne 'ok');
fail "expected response to be undefined, it wasn't" if (defined $response);
fail "expected response size 0, got $length" if ($length != 0);
