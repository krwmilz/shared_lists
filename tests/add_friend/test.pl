#!/usr/bin/perl -Itests

use strict;
use warnings;

use testlib;

# this test:
# - gets a new device id
# - then adds a new friend

my $sock = new_socket();
send_msg($sock, 0, "4038675309");
my ($type, $device_id, $length) = recv_msg($sock);

fail "got response type $type, expected 0" if ($type != 0);
fail "expected response length of 43, got $length" if ($length != 43);

send_msg($sock, 2, "$device_id\0" . "4033217654");
# my ($type2, $list_data, $length2) = recv_msg($sock);

# fail "got response type $type, expected 1" if ($type2 != 2);

# my ($id, $name, @members) = split("\0", $list_data);
# my $id_length = length($id);
# 
# fail "bad id length $id_length != 43" if ($id_length != 43);
# fail "recv'd name '$name' not equal to '$list_name'" if ($name ne $list_name);
# fail "list does not have exactly 1 member" if (@members != 1);
