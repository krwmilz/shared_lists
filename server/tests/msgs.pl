#!/usr/bin/perl
# generated Sat Jan  2 17:25:28 MST 2016
use strict;
use warnings;

our $protocol_ver = 0;
our %msg_num = (
	device_add => 0,
	device_ok => 1,
	friend_add => 2,
	friend_delete => 3,
	list_add => 4,
	list_join => 5,
	list_leave => 6,
	lists_get => 7,
	lists_get_other => 8,
	list_items_get => 9,
	list_item_add => 10,
);
our @msg_str = (
	'device_add',
	'device_ok',
	'friend_add',
	'friend_delete',
	'list_add',
	'list_join',
	'list_leave',
	'lists_get',
	'lists_get_other',
	'list_items_get',
	'list_item_add',
);
our @msg_func = (
	\&msg_device_add,
	\&msg_device_ok,
	\&msg_friend_add,
	\&msg_friend_delete,
	\&msg_list_add,
	\&msg_list_join,
	\&msg_list_leave,
	\&msg_lists_get,
	\&msg_lists_get_other,
	\&msg_list_items_get,
	\&msg_list_item_add,
);
