#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

my $A = client->new();

# Constructor automatically calls device_add so no need to do it here
my $devid = $A->device_id();
my $length = length($devid);
fail "device id '$devid' not base64" unless ($devid =~ m/^[a-zA-Z0-9+\/=]+$/);
fail "expected device id length of 43, got $length" if ($length != 43);

# Duplicate phone number
$A->device_add({ phone_number => $A->phnum, os => 'unix' }, 'err');
fail_msg_ne 'the sent phone number already exists', $A->get_error();

# Bad phone number
$A->device_add({ phone_number => '403867530&', os => 'unix' }, 'err');
fail_msg_ne 'the sent phone number is not a number', $A->get_error();

# Bad operating system
$A->device_add({ phone_number => rand_phnum(), os => 'bados' }, 'err');
fail_msg_ne 'operating system not supported', $A->get_error();

# Good operating systems
$A->device_add({ phone_number => rand_phnum(), os => 'android' });
$A->device_add({ phone_number => rand_phnum(), os => 'ios' });
