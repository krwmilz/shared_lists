#!/usr/bin/perl -I../
use strict;
use warnings;

use client;
use test;

# basic sanity check on the device_add message type
my $A = client->new();
my $phnum = $A->phnum;
my $devid = $A->device_id();
my $length = length($devid);
fail "device id '$devid' not base64" unless ($devid =~ m/^[a-zA-Z0-9+\/=]+$/);
fail "expected device id length of 43, got $length" if ($length != 43);

# try adding a device with a bad phone number 
$A->device_add('403867530&', 'unix', 'err');
fail_msg_ne 'the sent phone number is not a number', $A->get_error();

# try adding the same phone number again
$A->device_add($phnum, 'unix', 'err');
fail_msg_ne 'the sent phone number already exists', $A->get_error();

# send device_add with a bad operating system type
$A->device_add(rand_phnum(), 'bados', 'err');
fail_msg_ne 'operating system not supported', $A->get_error();
