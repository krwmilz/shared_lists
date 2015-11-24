#!/usr/bin/perl
# generated Sun Nov 22 23:36:41 MST 2015
use strict;
use warnings;

our $protocol_ver = 0;
our %msg_num = (
	new_device => 0,
	new_list => 1,
	add_friend => 2,
	join_list => 3,
	leave_list => 4,
	list_items => 5,
	new_list_item => 6,
	list_request => 7,
	ok => 8,
);
our @msg_str = (
	'new_device',
	'new_list',
	'add_friend',
	'join_list',
	'leave_list',
	'list_items',
	'new_list_item',
	'list_request',
	'ok',
);
our @msg_func = (
	\&msg_new_device,
	\&msg_new_list,
	\&msg_add_friend,
	\&msg_join_list,
	\&msg_leave_list,
	\&msg_list_items,
	\&msg_new_list_item,
	\&msg_list_request,
	\&msg_ok,
);
