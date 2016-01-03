#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

my $sock = new_socket();

# send a leave list message with a bad device id
send_msg($sock, 'list_leave', "somenonexistentdeviceid\0somelistid");
my ($msg_data) = recv_msg($sock, 'list_leave');

my $msg = check_status($msg_data, 'err');
my $msg_good = "the client sent an unknown device id";
fail "unexpected message '$msg', expected '$msg'" if ($msg ne $msg_good);

# send a message with a valid device id but bad list id
send_msg($sock, 'device_add', "4038675309\0unix");
($msg_data) = recv_msg($sock, 'device_add');

my $device_id = check_status($msg_data, 'ok');

send_msg($sock, 'list_leave', "$device_id\0somenonexistentlistid");
($msg_data) = recv_msg($sock, 'list_leave');

$msg = check_status($msg_data, 'err');
$msg_good = "the client sent an unknown list id";
fail "unexpected message '$msg', expected '$msg'" if ($msg ne $msg_good);
