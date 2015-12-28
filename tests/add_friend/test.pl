#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# this test:
# - gets a new device id
# - adds a new friend

my $sock = new_socket();

send_msg($sock, 'new_device', "4038675309\0unix");
my ($msg_data) = recv_msg($sock, 'new_device');

my $device_id = check_status($msg_data, 'ok');
my $friend_phnum = "4033217654";

send_msg($sock, 'add_friend', "$device_id\0$friend_phnum");
($msg_data) = recv_msg($sock, 'add_friend');

my $msg = check_status($msg_data, 'ok');
fail "got response ph num '$msg' expected '$friend_phnum'" if ($msg ne $friend_phnum);
