#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

my $sock = new_socket();

# send a leave list message with a bad device id
send_msg($sock, 'leave_list', "somenonexistentdeviceid\0somelistid");
my ($msg_data) = recv_msg($sock, 'leave_list');

my $msg = check_status($msg_data, 'err');
my $msg_good = "the client sent an unknown device id";
fail "unexpected message '$msg', expected '$msg'" if ($msg ne $msg_good);

# send a message with a valid device id but bad list id
send_msg($sock, 'new_device', "4038675309\0unix");
($msg_data) = recv_msg($sock, 'new_device');

my $device_id = check_status($msg_data, 'ok');

send_msg($sock, 'leave_list', "$device_id\0somenonexistentlistid");
($msg_data) = recv_msg($sock, 'leave_list');

$msg = check_status($msg_data, 'err');
$msg_good = "the client sent an unknown list id";
fail "unexpected message '$msg', expected '$msg'" if ($msg ne $msg_good);
