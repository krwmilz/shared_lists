#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# this test:
# - gets a new device id
# - creates some new lists
# - requests all lists
# - checks that what's received is what was sent

my $phone_num = "4038675309";
my $sock = new_socket();
send_msg($sock, $msg_num{new_device}, $phone_num);
my (undef, $device_id, undef) = recv_msg($sock);

my %list_id_map;
for my $name ("new list 1", "new list 2", "new list 3") {
	send_msg($sock, $msg_num{new_list}, "$device_id\0$name");
	my (undef, $data, undef) = recv_msg($sock);
	my ($id, $name, $member) = split("\0", $data);
	# save this for verification later
	$list_id_map{$name} = $id;
}

send_msg($sock, $msg_num{list_request}, $device_id);
my ($type, $list_data, $length) = recv_msg($sock);

if ($type != $msg_num{list_request}) {
	fail "got response type $type, expected $msg_num{list_request}"
}

my ($direct, $indirect) = split("\0\0", $list_data);
fail "got indirect lists, expected none" if (length($indirect) != 0);

for my $l (split("\0", $direct)) {
	my ($name, $id, @members) = split(":", $l);
	unless ($name && $id && @members) {
		fail "response didn't send at least 3 fields";
	}
	if ($list_id_map{$name} ne $id) {
		fail "recevied list id '$id' different than sent '$list_id_map{$name}'!";
	}
	if (@members != 1) {
		fail "expected 1 list member, got " . scalar @members . "\n";
	}
	if ($members[0] ne $phone_num) {
		fail "unexpected list member $members[0]";
	}
}
