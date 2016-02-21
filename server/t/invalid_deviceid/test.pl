#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

# test that sending invalid device id's results in errors

# Don't register
my $A = client->new(1);

my @device_ids = ('' , 'somebull$hit', 'legit');
my @good_msgs = ('the client sent a device id that was not base64',
	'the client sent a device id that was not base64',
	'the client sent an unknown device id'
);

for (0..2) {
	$A->set_device_id($device_ids[$_]);

	# for messages that send 2 arguments, send an empty 2nd argument
	my $err = $A->friend_add('', 'err');
	fail_msg_ne $good_msgs[$_], $err;

	$err = $A->friend_delete('', 'err');
	fail_msg_ne $good_msgs[$_], $err;

	$err = $A->list_add('', 'err');
	fail_msg_ne $good_msgs[$_], $err;

	$err = $A->list_join('', 'err');
	fail_msg_ne $good_msgs[$_], $err;

	$err = $A->list_leave('', 'err');
	fail_msg_ne $good_msgs[$_], $err;

	# messages that send 1 argument
	$err = $A->lists_get('err');
	fail_msg_ne $good_msgs[$_], $err;

	$err = $A->lists_get_other('err');
	fail_msg_ne $good_msgs[$_], $err;
}
