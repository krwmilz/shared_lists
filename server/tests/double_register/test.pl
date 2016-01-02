#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

my $sock = new_socket();

my $phnum = '4038675309';
send_msg($sock, 'device_add', "$phnum\0unix");
my ($msg_data) = recv_msg($sock, 'device_add');

check_status($msg_data, 'ok');

send_msg($sock, 'device_add', "$phnum\0unix");
($msg_data) = recv_msg($sock, 'device_add');

my $msg = check_status($msg_data, 'err');
my $msg_good = 'the sent phone number already exists';
fail "unexpected error message '$msg', was expecting '$msg_good'" if ($msg ne $msg_good);
