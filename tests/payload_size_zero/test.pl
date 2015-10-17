#!/usr/bin/perl -I..

use strict;
use warnings;

use testlib;

my $sock = new_socket();
send_msg($sock, 0, "");
close $sock;
