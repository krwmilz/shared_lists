use strict;
use Test;

# XXX: This test isn't very good
# - needs to check that server disconnects on these messages
BEGIN { plan tests => 1 }

use SL;

# Need a new connection every time because server disconnects on header errors.
my $server = SL::Server->new();

# Invalid message number
my $client = SL::Client->new(1);
$client->send_all(pack('nnn', 0, 47837, 0), 6);

# Bad protocol version
$client = SL::Client->new(1);
$client->send_all(pack('nnn', 101, 0, 0), 6);

# Payload length that's too long
$client = SL::Client->new(1);
$client->send_all(pack('nnn', 0, 0, 25143), 6);

# Advertised payload length longer than actual data length
$client = SL::Client->new(1);
$client->send_all(pack('nnnZ*', 0, 0, 5, 'ab'), 9);

# Truncated header
$client = SL::Client->new(1);
$client->send_all(pack('nn', 101, 69), 4);

ok(1);
