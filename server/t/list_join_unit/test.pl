#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

my $A = client->new();

# Try joining a list that doesn't exist
my $err = $A->list_join('12345678', 'err');
fail_msg_ne 'the client sent an unknown list number', $err;

# Test joining a list your already in
my $list = $A->list_add({ name => 'my new test list', date => 0 });
$err = $A->list_join($list->{num}, 'err');
fail_msg_ne 'the device is already part of this list', $err;
