#!/usr/bin/perl
# generated Sun Jan 24 15:51:04 MST 2016
use strict;
use warnings;

our $protocol_ver = 0;
our %msg_num = (
	device_add => 0,
	friend_add => 1,
	friend_delete => 2,
	list_add => 3,
	list_update => 4,
	list_join => 5,
	list_leave => 6,
	lists_get => 7,
	lists_get_other => 8,
	list_items_get => 9,
	list_item_add => 10,
);
our @msg_str = (
	'device_add',
	'friend_add',
	'friend_delete',
	'list_add',
	'list_update',
	'list_join',
	'list_leave',
	'lists_get',
	'lists_get_other',
	'list_items_get',
	'list_item_add',
);
our @msg_func = (
	\&msg_device_add,
	\&msg_friend_add,
	\&msg_friend_delete,
	\&msg_list_add,
	\&msg_list_update,
	\&msg_list_join,
	\&msg_list_leave,
	\&msg_lists_get,
	\&msg_lists_get_other,
	\&msg_list_items_get,
	\&msg_list_item_add,
);
