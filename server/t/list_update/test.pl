#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

my $A = client->new();

# Test sending a request with no 'num' key
my $err = $A->list_update({ name => 'some name' }, 'err');
fail_msg_ne 'the client did not send a list number', $err;

# Try and update a list that doesn't exist
$err = $A->list_update({ num => 123456, name => 'some name' }, 'err');
fail_msg_ne 'the client sent an unknown list number', $err;

# All checks after this require a valid list, create one now
my $list = $A->list_add({ name => 'this is a new list', date => 0 });

# Update only the list name first
$A->list_update({ num => $list->{num}, name => 'this is an updated name' });

# Verify the name change persisted
my @lists = @{ $A->lists_get() };
fail_msg_ne 'this is an updated name', $lists[0]->{name};
fail_num_ne 'date mismatch', $lists[0]->{date}, 0;

# Update only the date
$A->list_update({ num => $list->{num}, date => 12345 });

# Verify the date change persisted
@lists = @{ $A->lists_get() };
fail_msg_ne $lists[0]->{name}, 'this is an updated name';
fail_num_ne 'date mismatch', $lists[0]->{date}, 12345;

# Now update both the name and date
$A->list_update({ num => $list->{num}, date => 54321, name => 'updated again' });

@lists = @{ $A->lists_get() };
fail_msg_ne $lists[0]->{name}, 'updated again';
fail_num_ne 'date mismatch', $lists[0]->{date}, 54321;
