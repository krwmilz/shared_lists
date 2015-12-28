#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

my ($sock_1, $sock_2) = (new_socket(), new_socket());
my ($phnum_1, $phnum_2) = ("4038675309", "4037082094");

# create device 1 and 2
send_msg($sock_1, 'new_device', "$phnum_1\0unix");
my ($msg_data1) = recv_msg($sock_1, 'new_device');

send_msg($sock_2, 'new_device', "$phnum_2\0unix");
my ($msg_data2) = recv_msg($sock_2, 'new_device');

my $device_id1 = check_status($msg_data1, 'ok');
my $device_id2 = check_status($msg_data2, 'ok');

# make device 1 and 2 mutual friends
send_msg($sock_1, 'add_friend', "$device_id1\0$phnum_2");
recv_msg($sock_1, 'add_friend');
send_msg($sock_2, 'add_friend', "$device_id2\0$phnum_1");
recv_msg($sock_2, 'add_friend');

my $list_name = "this is a new list";

# device 1 creates new list
send_msg($sock_1, 'new_list', "$device_id1\0$list_name");
my ($msg_data) = recv_msg($sock_1, 'new_list');

my $msg = check_status($msg_data, 'ok');
my ($list_id) = unpack('Z*', $msg);

# device 2 joins the list
send_msg($sock_2, 'join_list', "$device_id2\0$list_id");
($msg_data) = recv_msg($sock_2, 'join_list');

check_status($msg_data, 'ok');

# device 2 requests its lists to make sure its committed to the list
send_msg($sock_2, 'list_get', $device_id2);
($msg_data) = recv_msg($sock_2, 'list_get');

my $list = check_status($msg_data, 'ok');
my ($id, $name, $num_items, @members) = split("\0", $list);

fail "request list id mismatch: '$id' ne '$list_id'" if ($id ne $list_id);
fail "unexpected name '$name', expected '$list_name'" if ($name ne $list_name);
fail "expected 2 list members, got ". @members if (@members != 2);
