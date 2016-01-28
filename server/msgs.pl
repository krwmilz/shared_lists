#!/usr/bin/perl
# generated Tue Jan 26 00:51:55 MST 2016
use strict;
use warnings;

our $protocol_ver = 0;
our %msg_num = (
	device_add => 0,
	device_update => 1,
	friend_add => 2,
	friend_delete => 3,
	list_add => 4,
	list_update => 5,
	list_join => 6,
	list_leave => 7,
	lists_get => 8,
	lists_get_other => 9,
	list_items_get => 10,
	list_item_add => 11,
);
our @msg_str = (
	'device_add',
	'device_update',
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
	\&msg_device_update,
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
