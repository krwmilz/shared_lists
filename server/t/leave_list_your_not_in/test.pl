#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

# Send a leave_list message that contains a valid list id but the requesting
# device is not currently a member of.

my $A = client->new();
my $B = client->new();

my $list = $A->list_add({ name => 'only a can see this list', date => 0 });

# Who knows how B got this list id, but he did
my $err = $B->list_leave($list->{num}, 'err');
fail_msg_ne 'the client was not a member of the list', $err;
