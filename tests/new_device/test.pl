#!/usr/bin/perl -I../
use strict;
use warnings;
use testlib;

my $sock = new_socket();
send_msg($sock, $msg_num{new_device}, "4038675309");
my ($type, $response, $length) = recv_msg($sock);
close $sock;

# verify response length is 32 random bytes encoded with base64
if ($length != 43) {
	fail "expected response length of 43, got $length";
}
