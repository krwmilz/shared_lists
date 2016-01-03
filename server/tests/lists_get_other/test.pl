#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# this test:
# - gets two new device id's
# - the two devices add each other mutually
# - device 1 creates a new list
# - then verify that device 2 can see it

my ($sock_1, $sock_2) = (new_socket(), new_socket());
my ($phnum_1, $phnum_2) = ("4038675309", "4037082094");

send_msg($sock_1, 'device_add', "$phnum_1\0unix");
my ($msg_1) = recv_msg($sock_1, 'device_add');

send_msg($sock_2, 'device_add', "$phnum_2\0unix");
my ($msg_2) = recv_msg($sock_2, 'device_add');

my $device_id1 = check_status($msg_1, 'ok');
my $device_id2 = check_status($msg_2, 'ok');

# the mutual friend relationship, computer style
send_msg($sock_1, 'friend_add', "$device_id1\0$phnum_2");
recv_msg($sock_1, 'friend_add');
send_msg($sock_2, 'friend_add', "$device_id2\0$phnum_1");
recv_msg($sock_2, 'friend_add');

my $list_name = "this is a new list";

send_msg($sock_1, 'list_add', "$device_id1\0$list_name");
my ($msg_data) = recv_msg($sock_1, 'list_add');

my $list_data = check_status($msg_data, 'ok');
my ($list_id) = split("\0", $list_data);

# make sure socket 2 can see socket 1's list
send_msg($sock_2, 'lists_get_other', $device_id2);
($msg_data) = recv_msg($sock_2, 'lists_get_other');

my $other_lists = check_status($msg_data, 'ok');
my $num_lists = 0;
for my $l (split("\n", $other_lists)) {
	my ($id, $name, @members) = split("\0", $l);
	unless ($id && $name && @members) {
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
