#!/usr/bin/perl -I../
use strict;
use warnings;

use client;
use test;

my $A = client->new();
$A->device_add(rand_phnum());

# first verify that a normal add_friend message succeeds
$A->friend_add('54321');

# add the same friend, again. not an error.
$A->friend_add('54321');

# verify that a non numeric friends phone number isn't accepted
$A->friend_add('123asdf', 'err');
fail_msg_ne 'friends phone number is not a valid phone number', $A->get_error();

# verify an empty phone number isn't accepted
$A->friend_add('', 'err');
fail_msg_ne 'friends phone number is not a valid phone number', $A->get_error();

# also verify adding yourself doesn't work
$A->friend_add($A->phnum(), 'err');
fail_msg_ne 'device cannot add itself as a friend', $A->get_error();
