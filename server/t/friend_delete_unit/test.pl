#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

my $A = client->new();

# try deleting someone who is not your friend
$A->friend_delete('12345', 'err');
fail_msg_ne 'friend sent for deletion was not a friend', $A->get_error();

# also verify that a non numeric friends phone number isn't accepted
$A->friend_delete('asdf123', 'err');
fail_msg_ne 'friends phone number is not a valid phone number', $A->get_error();

# also verify an empty phone number isn't accepted
$A->friend_delete('', 'err');
fail_msg_ne 'friends phone number is not a valid phone number', $A->get_error();
