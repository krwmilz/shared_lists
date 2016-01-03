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

send_msg($sock, 'device_add', "$phone_num\0unix");
my ($msg_data) = recv_msg($sock, 'device_add');

my $device_id = check_status($msg_data, 'ok');

my %list_id_map;
for my $name ("new list 1", "new list 2", "new list 3") {
	send_msg($sock, 'list_add', "$device_id\0$name");
	my ($msg_data) = recv_msg($sock, 'list_add');

	my $data = check_status($msg_data, 'ok');
	my ($id, $name, $member) = split("\0", $data);
	# save this for verification later
	$list_id_map{$name} = $id;
}

send_msg($sock, 'lists_get', $device_id);
($msg_data) = recv_msg($sock, 'lists_get');

my $lists = check_status($msg_data, 'ok');
my $num_lists = 0;
for my $l (split("\n", $lists)) {
	my ($id, $name, $num_items, @members) = split("\0", $l);
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
	$num_lists++;
}
fail "expected 3 direct lists, got $num_lists\n" if ($num_lists != 3);
