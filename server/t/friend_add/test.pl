#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

my $A = client->new();

# Normal message
$A->friend_add('54321');

# Re-add same friend
$A->friend_add('54321');

# Non numeric phone number
my $err = $A->friend_add('123asdf', 'err');
fail_msg_ne 'friends phone number is not a valid phone number', $err;

# Empty phone number
$err = $A->friend_add('', 'err');
fail_msg_ne 'friends phone number is not a valid phone number', $err;

# Friending yourself
$err = $A->friend_add($A->phnum(), 'err');
fail_msg_ne 'device cannot add itself as a friend', $err;
