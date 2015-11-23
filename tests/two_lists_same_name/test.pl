#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# this test:
# - gets a new device id
# - creates a new list

my $sock = new_socket();
send_msg($sock, 'new_device', "4038675309");
my ($type, $device_id, $length) = recv_msg($sock);

fail "got response type '$type', expected 'new_device" if ($type ne 'new_device');
fail "expected response length of 43, got $length" if ($length != 43);

my $list_name = "this is a new list";
send_msg($sock, 'new_list', "$device_id\0$list_name");
my ($type2, $list_data, $length2) = recv_msg($sock);

fail "got response type '$type', expected 'new_list'" if ($type2 ne 'new_list');

my ($id, $name, @members) = split("\0", $list_data);
my $id_length = length($id);

fail "bad id length $id_length != 43" if ($id_length != 43);
fail "recv'd name '$name' not equal to '$list_name'" if ($name ne $list_name);
fail "list does not have exactly 1 member" if (@members != 1);

# add the same list again
send_msg($sock, 'new_list', "$device_id\0$list_name");
($type2, $list_data, $length2) = recv_msg($sock);
