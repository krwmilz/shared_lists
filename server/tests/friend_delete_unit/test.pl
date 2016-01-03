#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

my $sock = new_socket();

# try deleting a friend with an unknown device id
send_msg($sock, 'friend_delete', "baddeviceid\0phnum");
my ($payload) = recv_msg($sock, 'friend_delete');

# expecting error because device id is bad
my $msg = check_status($payload, 'err');
my $msg_good = 'the client sent an unknown device id';
fail "unexpected message '$msg', expected '$msg_good'" if ($msg ne $msg_good);

# get a valid registration to use for the next tests
send_msg($sock, 'device_add', rand_phnum() . "\0unix");
($payload) = recv_msg($sock, 'device_add');

my $device_id = check_status($payload, 'ok');

# try deleting someone who is not your friend
send_msg($sock, 'friend_delete', "$device_id\0" . rand_phnum());
($payload) = recv_msg($sock, 'friend_delete');

$msg = check_status($payload, 'err');
$msg_good = 'friend sent for deletion was not a friend';
fail "unexpected message '$msg', expected '$msg_good'" if ($msg ne $msg_good);

# also verify that a non numeric friends phone number isn't accepted
send_msg($sock, 'friend_delete', "$device_id\0someshitnum123");
($payload) = recv_msg($sock, 'friend_delete');

$msg = check_status($payload, 'err');
$msg_good = 'friends phone number is not a valid phone number';
fail "unexpected message '$msg', expected '$msg_good'" if ($msg ne $msg_good);

# also verify an empty phone number isn't accepted
send_msg($sock, 'friend_delete', "$device_id\0");
($payload) = recv_msg($sock, 'friend_delete');

check_status($payload, 'err');
