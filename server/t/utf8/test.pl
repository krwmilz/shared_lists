#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

my $A = client->new();

# Create a new list with a name composed of 3 parts:
# - a left double quotation mark and
# - ae sorta character thing but where they touch
# - face with medical mask
$A->list_add({ name => "\xE2\x80\x9C \xC3\xA6 \xF0\x9F\x98\xB8", date => 0 });
my ($list) = @{ $A->lists_get() };

# Check the list name we get back hasn't been mangled in the round trip
fail_msg_ne "\xE2\x80\x9C \xC3\xA6 \xF0\x9F\x98\xB8", $list->{name};
