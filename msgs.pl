#!/usr/bin/perl
# generated Mon Dec 28 00:59:49 MST 2015
use strict;
use warnings;

our $protocol_ver = 0;
our %msg_num = (
	new_device => 0,
	add_friend => 1,
	new_list => 2,
	join_list => 3,
	leave_list => 4,
	list_get => 5,
	list_get_other => 6,
	list_items => 7,
	new_list_item => 8,
	ok => 9,
);
our @msg_str = (
	'new_device',
	'add_friend',
	'new_list',
	'join_list',
	'leave_list',
	'list_get',
	'list_get_other',
	'list_items',
	'new_list_item',
	'ok',
);
our @msg_func = (
	\&msg_new_device,
	\&msg_add_friend,
	\&msg_new_list,
	\&msg_join_list,
	\&msg_leave_list,
	\&msg_list_get,
	\&msg_list_get_other,
	\&msg_list_items,
	\&msg_new_list_item,
	\&msg_ok,
);
