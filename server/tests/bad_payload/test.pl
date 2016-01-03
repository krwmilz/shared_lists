#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# send message that's too long
send_msg(new_socket(), 'device_add', "longstr" x 1000);

# send message size 0 to all message types
my $sock = new_socket();
for (sort @msg_str) {
	send_msg($sock, $_, "");
	my ($msg_data) = recv_msg($sock, $_);

	my $msg = check_status($msg_data, 'err');
	my $msg_good = "wrong number of arguments";
	fail "unexpected error '$msg', expected '$msg_good'" if ($msg ne $msg_good);
}
