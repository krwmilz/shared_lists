#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# sanity checks the join_list message

my $socket = new_socket();
my $phnum = rand_phnum();

send_msg($socket, 'device_add', "$phnum\0unix");
my ($msg_data) = recv_msg($socket, 'device_add');

my $device_id = check_status($msg_data, 'ok');

# try joining a list that doesn't exist
send_msg($socket, 'list_join', "$device_id\0listdoesntexist");
($msg_data) = recv_msg($socket, 'list_join');

my $msg = check_status($msg_data, 'err');
my $msg_good = "the client sent an unknown list id";

fail "unexpected message '$msg', expected '$msg_good'" if ($msg ne $msg_good);

# test joining a list your already in
send_msg($socket, 'list_add', "$device_id\0some new list");
($msg_data) = recv_msg($socket, 'list_add');

$msg = check_status($msg_data, 'ok');
my ($list_id) = unpack('Z*', $msg);

send_msg($socket, 'list_join', "$device_id\0$list_id");
($msg_data) = recv_msg($socket, 'list_join');

$msg = check_status($msg_data, 'err');
$msg_good = "the device is already part of this list";

fail "unexpected message '$msg', expected '$msg_good'" if ($msg ne $msg_good);