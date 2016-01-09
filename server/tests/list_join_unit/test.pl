#!/usr/bin/perl -I../
use strict;
use warnings;

use client;
use test;

my $A = client->new();

# check that sending a list_join message without registering fails
$A->list_join('aaaa', 'err');
fail_msg_ne 'the client sent an unknown device id', $A->get_error();

# register this client for the next tests
$A->device_add(rand_phnum());

# try joining a list that doesn't exist
$A->list_join('somenonexistentlist', 'err');
fail_msg_ne 'the client sent an unknown list id', $A->get_error();

# test joining a list your already in
$A->list_add('my new test list');
$A->list_join($A->lists(0)->{'id'}, 'err');
fail_msg_ne 'the device is already part of this list', $A->get_error();
