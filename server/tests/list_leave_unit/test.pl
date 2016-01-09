#!/usr/bin/perl -I../
use strict;
use warnings;

use client;
use test;

my $A = client->new();

# send a leave list message with a bad device id
$A->list_leave('aaaa', 'err');
fail_msg_ne 'the client sent an unknown device id', $A->get_error();

$A->device_add();

# try leaving a list your not in
$A->list_leave('somenonexistentlistid', 'err');
fail_msg_ne 'the client sent an unknown list id', $A->get_error();

# try leaving the empty list
$A->list_leave('', 'err');
fail_msg_ne 'the client sent an unknown list id', $A->get_error();
