#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

# Send a leave_list message that contains a valid list id but the requesting
# device is not currently a member of.

my $A = client->new();
my $B = client->new();

$A->list_add('only a can see this list');

# Who knows how B got this list id, but he did
$B->list_leave($A->lists(0)->{num}, 'err');
fail_msg_ne 'the client was not a member of the list', $B->get_error();
