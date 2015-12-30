#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# this test:
# - gets a new device id
# - adds a new friend

my $sock = new_socket();
my $friend1 = "4033217654";
my $friend2 = "4033217654bad";
my $msg_good = "friends phone number is not a valid phone number";

send_msg($sock, 'new_device', "4038675309\0unix");
my ($msg_data) = recv_msg($sock, 'new_device');

my $device_id = check_status($msg_data, 'ok');

# first verify that a normal add_friend message succeeds
send_msg($sock, 'add_friend', "$device_id\0$friend1");
($msg_data) = recv_msg($sock, 'add_friend');

my $phnum = check_status($msg_data, 'ok');
fail "got response ph num '$phnum' expected '$friend1'" if ($phnum ne $friend1);

# also verify that a non numeric friends phone number isn't accepted
send_msg($sock, 'add_friend', "$device_id\0$friend2");
($msg_data) = recv_msg($sock, 'add_friend');

my $msg = check_status($msg_data, 'err');
fail "unexpected error message '$msg', expecting '$msg_good'" if ($msg ne $msg_good);

# also verify an empty phone number isn't accepted
send_msg($sock, 'add_friend', "$device_id\0");
($msg_data) = recv_msg($sock, 'add_friend');

$msg = check_status($msg_data, 'err');
fail "unexpected error message '$msg', expecting '$msg_good'" if ($msg ne $msg_good);
