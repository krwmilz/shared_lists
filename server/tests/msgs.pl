#!/usr/bin/perl
# generated 'Sat Jan  2 16:41:19 MST 2016'
use strict;
use warnings;

our $protocol_ver = 0;
our %msg_num = (
	device_add => 0,
	device_ok => 1,
	friend_add => 2,
	list_add => 3,
	list_join => 4,
	list_leave => 5,
	lists_get => 6,
	lists_get_other => 7,
	list_items_get => 8,
	list_item_add => 9,
);
our @msg_str = (
	'device_add',
	'device_ok',
	'friend_add',
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
	\&msg_list_add,
	\&msg_list_join,
	\&msg_list_leave,
	\&msg_lists_get,
	\&msg_lists_get_other,
	\&msg_list_items_get,
	\&msg_list_item_add,
);
