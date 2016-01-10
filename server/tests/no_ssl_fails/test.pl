#!/usr/bin/perl -I../
use strict;
use warnings;

use IO::Socket::INET;
use Time::HiRes qw(usleep);
use test;

# check that a non-ssl connection isn't accepted
my $socket;
my $timeout = time + 5;
while (1) {
	$socket = new IO::Socket::INET(
		PeerHost => 'localhost',
		PeerPort => $ENV{PORT} || 5437,
	);

	if ($!{ECONNREFUSED}) {
		if (time > $timeout) {
			fail "server not ready after 5 seconds";
		}
		usleep(50 * 1000);
		next;
	}

	last;
}

my $good_errno = 'Illegal seek';
fail "expected errno '$good_errno' but got '$!'" if ($! ne $good_errno);
