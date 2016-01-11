#!/usr/bin/perl -I../
use strict;
use warnings;

use client;

# Message header sanity checks. A new connection needed every time because
# server will disconnect on header errors.

# send an invalid message number
my $client = client->new(1);
$client->send_all(pack('nnn', 0, 47837, 0), 6);

# send a bad protocol version
$client = client->new(1);
$client->send_all(pack('nnn', 101, 0, 0), 6);

# send a message length that's too long
$client = client->new(1);
$client->send_all(pack('nnn', 0, 0, 25143), 6);

# send a message length that's larger than the actual data sent
$client = client->new(1);
$client->send_all(pack('nnnZ*', 0, 0, 5, 'ab'), 9);

# send a partial header
$client = client->new(1);
$client->send_all(pack('nn', 101, 69), 4);
