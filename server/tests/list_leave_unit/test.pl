#!/usr/bin/perl -I../
use strict;
use warnings;

use client;
use test;

my $A = client->new();

# try leaving a list your not in
$A->list_leave('somenonexistentlistid', 'err');
fail_msg_ne 'the client sent an unknown list id', $A->get_error();

# try leaving the empty list
$A->list_leave('', 'err');
fail_msg_ne 'the client sent an unknown list id', $A->get_error();
