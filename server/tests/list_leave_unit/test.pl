#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

my $A = client->new();

# Try leaving a list your not in
$A->list_leave('1234567', 'err');
fail_msg_ne 'the client sent an unknown list number', $A->get_error();

# Try leaving the empty list
$A->list_leave('', 'err');
fail_msg_ne 'the client sent a list number that was not a number', $A->get_error();
