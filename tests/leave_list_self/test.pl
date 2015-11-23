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
my $send_t = 'new_device';
send_msg($sock, $send_t, "4038675309");
my (undef, $device_id, undef) = recv_msg($sock);

my $list_name = "this is a new list";
send_msg($sock, 'new_list', "$device_id\0$list_name");
my (undef, $list_data, undef) = recv_msg($sock);
my ($list_id) = split("\0", $list_data);

send_msg($sock, 'leave_list', "$device_id\0$list_id");
my ($recv_t, $leave_data, $length) = recv_msg($sock);

my ($leave_id) = split("\0", $leave_data);
fail "message type mismatch, '$recv_t' != 'leave_list'" if ($recv_t ne 'leave_list');
fail "got leave data '$leave_id', expected $list_id" if ($leave_id ne $list_id);

# verify we don't get this list back when requesting all lists
send_msg($sock, 'list_request', $device_id);
my (undef, $request_data, $length2) = recv_msg($sock);

my ($direct, $other) = split("\0\0", $request_data);
fail "expected empty, got other" if ($direct ne "" || $other ne "");
