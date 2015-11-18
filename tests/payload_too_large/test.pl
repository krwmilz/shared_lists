#!/usr/bin/perl -I../

use strict;
use warnings;

use testlib;

my $sock = new_socket();

# make a long string the stupid way, 4000 bytes
my $out;
$out .= "asdf" for (1..1000);

send_msg($sock, 0, $out);
close $sock;
