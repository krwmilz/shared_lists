#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# this test:
# - tries to send every message type with an invalid id
# - except for new_device message type

my $sock = new_socket();
for my $msg (sort @msg_str) {
	# new device doesn't take device id as a first parameter
	next if ($msg eq "new_device");
	send_msg($sock, $msg_num{$msg}, "notvaliddeviceid");
}
