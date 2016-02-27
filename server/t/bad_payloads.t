use strict;
use Test::More tests => 1;

use_ok( 'SL' );

my $server = SL::Server->new();

# Send a straight up unparsable json string
my $client = SL::Client->new(1);
$client->send_all(pack('nnnZ*', 0, 0, 2, "{"), 8);

# Send an empty array back (which is valid json but we don't use this)
$client = SL::Client->new(1);
$client->send_all(pack('nnnZ*', 0, 0, 2, "[]"), 9);
