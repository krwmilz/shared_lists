#!/usr/bin/perl -I../
use strict;
use warnings;

use client;
use test;

my $A = client->new();

# try joining a list that doesn't exist
$A->list_join('12345678', 'err');
fail_msg_ne 'the client sent an unknown list number', $A->get_error();

# test joining a list your already in
$A->list_add('my new test list');
$A->list_join($A->lists(0)->{'id'}, 'err');
fail_msg_ne 'the device is already part of this list', $A->get_error();
