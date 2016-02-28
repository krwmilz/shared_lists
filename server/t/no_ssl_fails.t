use strict;
use IO::Socket::INET;
use Test;
use SL::Test;
use Time::HiRes qw(usleep);

BEGIN { plan tests => 1 }

# Check that a non-SSL connection isn't accepted

my $s = SL::Test::Server->new();

my $socket = undef;
while (!defined $socket) {
	$socket = new IO::Socket::INET(
		PeerHost => 'localhost',
		PeerPort => 4729,
	) or usleep(100 * 1000);
}

my $good_errno = 'Illegal seek';
$socket->syswrite("a\0\0\0" x 787);

my $ssl_err = '';
if ($^O eq 'linux') {
	$ssl_err = '/SSL accept attempt failed with unknown error error:140760FC:SSL routines:SSL23_GET_CLIENT_HELLO:unknown protocol/';
}
elsif ($^O eq 'openbsd') {
	$ssl_err = '/SSL accept attempt failed error:140760FC:SSL routines:SSL23_GET_CLIENT_HELLO:unknown protocol/';
}

ok( $s->readline(), $ssl_err );
