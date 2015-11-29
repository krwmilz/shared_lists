#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# this test:
# - gets two new device id's
# - the two devices add each other mutually
# - device 1 creates a new list
# - then verify that device 2 can see it

my $sock_1 = new_socket();
my $phnum_1 ="4038675309";
send_msg($sock_1, 'new_device', $phnum_1);
my (undef, $device_id1, undef) = recv_msg($sock_1);

my $sock_2 = new_socket();
my $phnum_2 = "4037082094";
send_msg($sock_2, 'new_device', $phnum_2);
my (undef, $device_id2, undef) = recv_msg($sock_2);

# the mutual friend relationship, computer style
send_msg($sock_1, 'add_friend', "$device_id1\0$phnum_2");
recv_msg($sock_1);
send_msg($sock_2, 'add_friend', "$device_id2\0$phnum_1");
recv_msg($sock_2);

my $list_name = "this is a new list";
send_msg($sock_1, 'new_list', "$device_id1\0$list_name");
my (undef, $list_data, undef) = recv_msg($sock_1);
my ($list_id) = split("\0", $list_data);

# make sure socket 2 can see socket 1's list
send_msg($sock_2, 'list_request', $device_id2);
my (undef, $request_data, $request_len) = recv_msg($sock_2);
my (undef, $other) = split("\0\0", $request_data);

my $num_lists = 0;
for my $l (split("\0", $other)) {
	my ($name, $id, @members) = split(":", $l);
	unless ($name && $id && @members) {
		fail "response didn't send at least 3 fields";
	}
	if ($list_id ne $id) {
		fail "recevied list id '$id' different than sent '$list_id'!";
	}
	if (@members != 1) {
		fail "expected 1 list member, got " . scalar @members . "\n";
	}
	if ($members[0] ne $phnum_1) {
		fail "unexpected list member '$members[0]'";
	}
	$num_lists++;
}
fail "expected 1 indirect list, got $num_lists\n" if ($num_lists != 1);
