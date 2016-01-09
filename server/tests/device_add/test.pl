#!/usr/bin/perl -I../
use strict;
use warnings;

use client;
use test;

my $A = client->new();

# basic sanity check on the device_add message type
my $phnum = rand_phnum();
$A->device_add($phnum);

my $devid = $A->device_id();
my $length = length($devid);
fail "device id '$devid' not base64" unless ($devid =~ m/^[a-zA-Z0-9+\/=]+$/);
fail "expected device id length of 43, got $length" if ($length != 43);

# try adding a device with a bad phone number 
$A->device_add('403867530&', 'err');
fail_msg_ne 'the sent phone number is not a number', $A->get_error();

# try adding the same phone number again
$A->device_add($phnum, 'err');
fail_msg_ne 'the sent phone number already exists', $A->get_error();
