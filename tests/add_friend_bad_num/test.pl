#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# this test:
# - gets a new device id
# - tries adding a new friend with a non numeric phone number

my $sock = new_socket();

send_msg($sock, 'new_device', "4038675309\0unix");
my ($msg_data) = recv_msg($sock, 'new_device');

my $device_id = check_status($msg_data, 'ok');
my $friend_phnum = "4033217654bad";

send_msg($sock, 'add_friend', "$device_id\0$friend_phnum");
($msg_data) = recv_msg($sock, 'add_friend');

my $msg = check_status($msg_data, 'err');
my $msg_good = "friends phone number is not a valid phone number";
fail "unexpected error message '$msg', was expecting '$msg_good'" if ($msg ne $msg_good);
