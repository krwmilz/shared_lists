#!/usr/bin/perl -I../
use strict;
use warnings;
use client;

# Need a new connection every time because server disconnects on header errors.

# Invalid message number
my $client = client->new(1);
$client->send_all(pack('nnn', 0, 47837, 0), 6);

# Bad protocol version
$client = client->new(1);
$client->send_all(pack('nnn', 101, 0, 0), 6);

# Payload length that's too long
$client = client->new(1);
$client->send_all(pack('nnn', 0, 0, 25143), 6);

# Advertised payload length longer than actual data length
$client = client->new(1);
$client->send_all(pack('nnnZ*', 0, 0, 5, 'ab'), 9);

# Truncated header
$client = client->new(1);
$client->send_all(pack('nn', 101, 69), 4);
