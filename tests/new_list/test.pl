#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# this test:
# - gets a new device id
# - creates a new list
# - receives new list response
# - verifies received information is congruent with what was sent

my $sock = new_socket();
my $send_t = 'new_device';
my $phnum = "4038675309";
send_msg($sock, $send_t, $phnum);
my ($recv_t, $device_id, $length) = recv_msg($sock);

fail "got response type '$recv_t', expected '$send_t'" if ($recv_t ne $send_t);
fail "expected response length of 43, got $length" if ($length != 43);

my $list_name = "this is a new list";
$send_t = 'new_list';
send_msg($sock, $send_t, "$device_id\0$list_name");
my ($recv_t2, $list_data, $length2) = recv_msg($sock);

fail "got response type '$recv_t2', expected '$send_t'" if ($recv_t2 ne $send_t);

my ($id, $name, @members) = split("\0", $list_data);
my $id_length = length($id);

fail "bad id length $id_length != 43" if ($id_length != 43);
fail "recv'd name '$name' not equal to '$list_name'" if ($name ne $list_name);
fail "list does not have exactly 1 member" if (@members != 1);
fail "got list member '$members[0]', expected '$phnum'" if ($members[0] ne $phnum);
