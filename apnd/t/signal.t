use strict;
use Test;

BEGIN { plan tests => 1 }

use APND;
use JSON::XS;

my $server = APND::Server->new();
my $socket = APND::Socket->new();

$server->kill();
ok($server->readline(), "/caught signal terminated: shutting down/");
