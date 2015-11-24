#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# this test:
# - gets a new device id
# - tries adding a new friend with a bad phone number

my $sock = new_socket();
send_msg($sock, 'new_device', "4038675309");
my (undef, $device_id, undef) = recv_msg($sock);

my $friend_phnum = "4033217654bad";
send_msg($sock, 'add_friend', "$device_id\0$friend_phnum");
