#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

my $A = client->new();

# Someone who is not your friend
my $err = $A->friend_delete('12345', 'err');
fail_msg_ne 'friend sent for deletion was not a friend', $err;

# Non numeric friends phone number
$err = $A->friend_delete('asdf123', 'err');
fail_msg_ne 'friends phone number is not a valid phone number', $err;

# Empty phone number
$err = $A->friend_delete('', 'err');
fail_msg_ne 'friends phone number is not a valid phone number', $err;

# Add/delete cycle works
$A->friend_add('12345');
$A->friend_delete('12345');
