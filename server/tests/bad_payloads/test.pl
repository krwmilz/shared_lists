#!/usr/bin/perl -I../
use strict;
use warnings;
use client;

# Send a straight up unparsable json string
my $client = client->new(1);
$client->send_all(pack('nnnZ*', 0, 0, 2, "{"), 8);

# Send an empty array back (which is valid json but we don't use this)
$client = client->new(1);
$client->send_all(pack('nnnZ*', 0, 0, 2, "[]"), 9);
