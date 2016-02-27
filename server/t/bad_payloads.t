use strict;
use Test;
use TestSL;

BEGIN { plan tests => 1 }

my $s = TestSL::Server->new();

# Send a straight up unparsable json string
my $client = TestSL::Client->new(1);
$client->send_all(pack('nnnZ*', 0, 0, 2, "{"), 8);

# Send an empty array back (which is valid json but we don't use this)
$client = TestSL::Client->new(1);
$client->send_all(pack('nnnZ*', 0, 0, 2, "[]"), 9);

ok(1);
