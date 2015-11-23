#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# this test:
# - gets a new device id
# - adds a new friend

my $sock = new_socket();
send_msg($sock, 'new_device', "4038675309");
my (undef, $device_id, undef) = recv_msg($sock);

my $friend_phnum = "4033217654";
my $send_t = 'add_friend';
send_msg($sock, $send_t, "$device_id\0$friend_phnum");
my ($recv_t, $resp_data, $length) = recv_msg($sock);

fail "got response type '$recv_t', expected '$send_t'" if ($recv_t ne $send_t);
fail "got response ph num '$resp_data' expected '$friend_phnum'" if ($resp_data ne $friend_phnum);
