#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

my $sock = new_socket();

for my $msg_type (sort @msg_str) {
	# new device doesn't take device id as a first parameter
	next if ($msg_type eq "new_device");

	# send a valid base64 but not yet registered device id
	send_msg($sock, $msg_type, "notvaliddeviceid");
	my ($msg_data) = recv_msg($sock, $msg_type);

	my $msg = check_status($msg_data, 'err');
	my $msg_good = 'the client sent an unknown device id';
	fail "got unexpected error message '$msg', expected '$msg_good'" if ($msg ne $msg_good);

	# send an invalid base64 id
	send_msg($sock, $msg_type, "&^%_invalid_base64");
	($msg_data) = recv_msg($sock, $msg_type);

	$msg = check_status($msg_data, 'err');
	$msg_good = 'the client sent a device id that wasn\'t base64';
	fail "got unexpected error message '$msg', expected '$msg_good'" if ($msg ne $msg_good);
}
