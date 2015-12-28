#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# this test:
# - creates a new device
# - creates a new list
# - leaves that list
# - verifies list is gone

my $sock = new_socket();

send_msg($sock, 'new_device', "4038675309");
my ($msg_data) = recv_msg($sock, 'new_device');

my $device_id = check_status($msg_data, 'ok');
my $list_name = "this is a new list";

send_msg($sock, 'new_list', "$device_id\0$list_name");
($msg_data) = recv_msg($sock, 'new_list');

my $msg = check_status($msg_data, 'ok');
my ($list_id) = split("\0", $msg);

send_msg($sock, 'leave_list', "$device_id\0$list_id");
($msg_data) = recv_msg($sock, 'leave_list');

$msg = check_status($msg_data, 'ok');
my ($leave_id) = split("\0", $msg);
fail "got leave data '$leave_id', expected $list_id" if ($leave_id ne $list_id);

# verify we don't get this list back when requesting all lists
send_msg($sock, 'list_get', $device_id);
($msg_data) = recv_msg($sock, 'list_get');

my $lists = check_status($msg_data, 'ok');
fail "expected no lists" if ($lists ne "");
