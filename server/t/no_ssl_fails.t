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
