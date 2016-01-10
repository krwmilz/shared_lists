#!/usr/bin/perl -I../
use strict;
use warnings;

use client;
use test;

# test that sending invalid device id's results in errors

my $A = client->new();
$A->set_device_id("");

# for messages that send 2 arguments, send an empty 2nd argument
$A->friend_add('', 'err');
fail_msg_ne 'the client sent an unknown device id', $A->get_error();

$A->friend_delete('', 'err');
fail_msg_ne 'the client sent an unknown device id', $A->get_error();

$A->list_add('', 'err');
fail_msg_ne 'the client sent an unknown device id', $A->get_error();

$A->list_join('', 'err');
fail_msg_ne 'the client sent an unknown device id', $A->get_error();

$A->list_leave('', 'err');
fail_msg_ne 'the client sent an unknown device id', $A->get_error();

$A->lists_get('err');
fail_msg_ne 'the client sent an unknown device id', $A->get_error();

$A->lists_get_other('err');
fail_msg_ne 'the client sent an unknown device id', $A->get_error();
