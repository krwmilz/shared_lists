#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# send message that's too long
send_msg(new_socket(), 'new_device', "longstr" x 1000);

# send message size 0 to all message types
# reuse a socket because we shouldn't get disconnected for this
my $sock = new_socket();
for (@msg_str) {
	send_msg($sock, $_, "");
	my ($msg_data) = recv_msg($sock, $_);

	my $msg = check_status($msg_data, 'err');
	# print "$msg\n";
}
