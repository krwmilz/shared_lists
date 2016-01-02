#!/usr/bin/perl -I../
use strict;
use warnings;
use test;

# this test sanity checks the new_list message. it checks that
# - a new list can be created, and has the correct fields
# - a list with no name is rejected

my $sock = new_socket();
my $phnum = "4038675309";
my $list_name = "this is a new list";

send_msg($sock, 'new_device', "$phnum\0unix");
my ($payload) = recv_msg($sock, 'new_device');

my $device_id = check_status($payload, 'ok');

# verify a normal new_list request succeeds and returns good information
send_msg($sock, 'new_list', "$device_id\0$list_name");
($payload) = recv_msg($sock, 'new_list');

my $list_data = check_status($payload, 'ok');
my ($id, $name, @members) = split("\0", $list_data);
my $id_length = length($id);

fail "bad id length $id_length != 43" if ($id_length != 43);
fail "recv'd name '$name' not equal to '$list_name'" if ($name ne $list_name);
fail "list does not have exactly 1 member" if (@members != 1);
fail "got list member '$members[0]', expected '$phnum'" if ($members[0] ne $phnum);

# verify a new_list request with an empty list name succeeds
send_msg($sock, 'new_list', "$device_id\0");
($payload) = recv_msg($sock, 'new_list');

my $msg = check_status($payload, 'ok');
