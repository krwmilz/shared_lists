#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# this test:
# - creates new device id
# - creates new list
# - creates another new list with identical name

my $sock = new_socket();

send_msg($sock, 'new_device', "4038675309\0unix");
my ($msg_data, $length) = recv_msg($sock, 'new_device');

my $device_id = check_status($msg_data, 'ok');
my $list_name = "this is a new list";

send_msg($sock, 'new_list', "$device_id\0$list_name");
($msg_data) = recv_msg($sock, 'new_list');

check_status($msg_data, 'ok');

# add the same list again
send_msg($sock, 'new_list', "$device_id\0$list_name");
($msg_data, $length) = recv_msg($sock, 'new_list');

my $msg = check_status($msg_data, 'ok');
