#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# this test makes sure that when 2 friends of yours are in the same list that
# your not in, that the list doesn't show up twice in your list_get_other
# request.

my ($sockets, $phnums, $device_ids) = create_devices(3);

# 0 and 1 need to be mutual friends
send_msg($$sockets[0], 'add_friend', "$$device_ids[0]\0$$phnums[1]");
recv_msg($$sockets[0], 'add_friend');
send_msg($$sockets[1], 'add_friend', "$$device_ids[1]\0$$phnums[0]");
recv_msg($$sockets[1], 'add_friend');

# 0 and 2 need to be mutual friends too
send_msg($$sockets[0], 'add_friend', "$$device_ids[0]\0$$phnums[2]");
recv_msg($$sockets[0], 'add_friend');
send_msg($$sockets[2], 'add_friend', "$$device_ids[2]\0$$phnums[0]");
recv_msg($$sockets[2], 'add_friend');

# 1 and 2 need to be in the same list
send_msg($$sockets[1], 'new_list', "$$device_ids[1]\0this is a new list");
my ($msg_data) = recv_msg($$sockets[1], 'new_list');

my $list_data = check_status($msg_data, 'ok');
my ($list_id) = split("\0", $list_data);

send_msg($$sockets[2], 'join_list', "$$device_ids[2]\0$list_id");
($msg_data) = recv_msg($$sockets[2], 'join_list');

check_status($msg_data, 'ok');

# 0 requests his other lists
send_msg($$sockets[0], 'list_get_other', "$$device_ids[0]");
($msg_data) = recv_msg($$sockets[0], 'list_get_other');

my $raw_lists = check_status($msg_data, 'ok');
my @lists = split("\n", $raw_lists);
fail "expected 1 list, got " . @lists if (@lists != 1);

# 0 makes sure he got a single list with both members in it
my ($id, $name, @members) = split("\0", $lists[0]);
fail "expected 2 list members, got " . @members if (@members != 2);
fail "bad list id '$id', expected '$list_id'" if ($id ne $list_id);
fail "expected member '$$phnums[1]'" unless (grep {$_ eq $$phnums[1]} @$phnums);
fail "expected member '$$phnums[2]'" unless (grep {$_ eq $$phnums[2]} @$phnums);
