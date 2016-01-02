#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# verify basic leave_list scenario where you create a list then leave it

my $sock = new_socket();
my $list_name = "this is a new list";

# create a new device id
send_msg($sock, 'device_add', "4038675309\0unix");
my ($msg_data) = recv_msg($sock, 'device_add');

my $device_id = check_status($msg_data, 'ok');

# create a new list
send_msg($sock, 'list_add', "$device_id\0$list_name");
($msg_data) = recv_msg($sock, 'list_add');

my $msg = check_status($msg_data, 'ok');
my ($list_id) = split("\0", $msg);

# leave the list
send_msg($sock, 'list_leave', "$device_id\0$list_id");
($msg_data) = recv_msg($sock, 'list_leave');

$msg = check_status($msg_data, 'ok');
my ($leave_id) = split("\0", $msg);
fail "got leave data '$leave_id', expected $list_id" if ($leave_id ne $list_id);

# verify we don't get this list back when requesting all lists
send_msg($sock, 'lists_get', $device_id);
($msg_data) = recv_msg($sock, 'lists_get');

my $lists = check_status($msg_data, 'ok');
fail "expected no lists" if ($lists ne "");

# verify we don't get this list back when requesting other lists
send_msg($sock, 'lists_get_other', $device_id);
($msg_data) = recv_msg($sock, 'lists_get_other');

$lists = check_status($msg_data, 'ok');
fail "expected no lists" if ($lists ne "");
