#!/usr/bin/perl -I../
use strict;
use warnings;

use IO::Socket::INET;
use Time::HiRes qw(usleep);
use test;

# check that a non-ssl connection isn't accepted
my $socket = new IO::Socket::INET(
	PeerHost => 'localhost',
	PeerPort => $ENV{PORT} || 5437,
);

my $good_errno = 'Illegal seek';
$socket->syswrite("a\0\0\0" x 787);
my $ret = $socket->sysread(my $buf, 6);
#fail "expected errno '$good_errno' but got '$!'" if ($! ne $good_errno);
fail "sysread returned '$ret', expected '0'" if ($ret != 0);
