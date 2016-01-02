#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# this is a test for list lifetime, especially when the creator of the list
# leaves. it makes sure that when A creates a list, then B joins, and then A
# leaves, that the list does not get deleted and is still accessible to B.

my ($sockets, $phnums, $device_ids) = create_devices(2);
my $list_name = "this is a new list";

# A creates a new list
send_msg($$sockets[0], 'new_list', "$$device_ids[0]\0$list_name");
my ($msg_data) = recv_msg($$sockets[0], 'new_list');

my $msg = check_status($msg_data, 'ok');
my ($list_id) = split("\0", $msg);

# B joins the list
send_msg($$sockets[1], 'join_list', "$$device_ids[1]\0$list_id");
($msg_data) = recv_msg($$sockets[1], 'join_list');

check_status($msg_data, 'ok');

# A leaves the list
send_msg($$sockets[0], 'leave_list', "$$device_ids[0]\0$list_id");
($msg_data) = recv_msg($$sockets[0], 'leave_list');

$msg = check_status($msg_data, 'ok');

# B verifies its still in the list
send_msg($$sockets[1], 'list_get', $$device_ids[1]);
($msg_data) = recv_msg($$sockets[1], 'list_get');

my $lists = check_status($msg_data, 'ok');
my @lists = split("\n", $lists);
fail "expected 1 list, got " . @lists if (@lists != 1);

# B also leaves the list
send_msg($$sockets[1], 'leave_list', "$$device_ids[1]\0$list_id");
($msg_data) = recv_msg($$sockets[1], 'leave_list');

$msg = check_status($msg_data, 'ok');
