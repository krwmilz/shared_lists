#!/usr/bin/perl -I../
use strict;
use warnings;

use IO::Socket::INET;
use Time::HiRes qw(usleep);
use test;

# Wait until a successful connection can be made, or timeout.
# This must be the first test because other tests do not have connection
# retries and will assume that a connectible server is up and ready.

my $socket;
my $timeout = time + 3;
while (1) {
	$socket = new IO::Socket::INET(
		PeerHost => 'localhost',
		PeerPort => $ENV{PORT} || 5437,
	);

	# Connection refused, ie server has not called listen() yet
	if ($!{ECONNREFUSED}) {
		fail "server not ready after 3 seconds" if (time > $timeout);
		usleep(100 * 1000);

		next;
	}

	# We got some non Connection refused return code
	last;
}

fail "socket not good" unless ($socket);
$socket->syswrite("a\0\0\0"x 3);
$socket->sysread(my $buf, 1);
