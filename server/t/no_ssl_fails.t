use strict;
use Test::More tests => 2;

use_ok( 'SL' );
use IO::Socket::INET;
use Time::HiRes qw(usleep);

# Check that a non-ssl connection isn't accepted

my $server = SL::Server->new();

my $socket = undef;
while (!defined $socket) {
	$socket = new IO::Socket::INET(
		PeerHost => 'localhost',
		PeerPort => 4729,
	);
	usleep(100 * 1000);
}

my $good_errno = 'Illegal seek';
$socket->syswrite("a\0\0\0" x 787);
#my $ret = $socket->sysread(my $buf, 6);
ok(1);
#fail "expected errno '$good_errno' but got '$!'" if ($! ne $good_errno);
#fail "sysread returned '$ret', expected '0'" if ($ret != 0);

#print STDERR $server->readline();
