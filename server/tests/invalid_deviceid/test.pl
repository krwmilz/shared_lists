#!/usr/bin/perl -I../
use strict;
use warnings;

use client;
use test;

# test that sending invalid device id's results in errors

my $A = client->new(1);
my @device_ids = ('', 'somebull$hit');
my @good_msgs = ('the client sent an unknown device id',
	'the client sent a device id that was not base64');

for (0..1) {
	$A->set_device_id($device_ids[$_]);

	# for messages that send 2 arguments, send an empty 2nd argument
	$A->friend_add('', 'err');
	fail_msg_ne $good_msgs[$_], $A->get_error();

	$A->friend_delete('', 'err');
	fail_msg_ne $good_msgs[$_], $A->get_error();

	$A->list_add('', 'err');
	fail_msg_ne $good_msgs[$_], $A->get_error();

	$A->list_join('', 'err');
	fail_msg_ne $good_msgs[$_], $A->get_error();

	$A->list_leave('', 'err');
	fail_msg_ne $good_msgs[$_], $A->get_error();

	# messages that send 1 argument
	$A->lists_get('err');
	fail_msg_ne $good_msgs[$_], $A->get_error();

	$A->lists_get_other('err');
	fail_msg_ne $good_msgs[$_], $A->get_error();
}
