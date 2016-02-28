use strict;
use Test;
use SL::Test;

BEGIN { plan tests => 6 }

# Need a new connection every time because server disconnects on header errors.
my $s = SL::Test::Server->new();

# Invalid message number
my $client = SL::Test::Client->new(1);
$client->send_all(pack('nnn', 0, 47837, 0), 6);
ok($s->readline(), '/error: unknown message type 47837/');

# Bad protocol version
$client = SL::Test::Client->new(1);
$client->send_all(pack('nnn', 101, 0, 0), 6);
ok($s->readline(), '/error: unsupported protocol version 101/');

# Payload length that's too long
$client = SL::Test::Client->new(1);
$client->send_all(pack('nnn', 0, 0, 25143), 6);
ok($s->readline(), '/error: 25143 byte payload invalid/');

# Advertised payload length longer than actual data length
$client = SL::Test::Client->new(1);
$client->send_all(pack('nnnZ*', 0, 0, 5, 'ab'), 9);

# Truncated header
$client = SL::Test::Client->new(1);
$client->send_all(pack('nn', 101, 69), 4);
ok($s->readline(), '/disconnected!/');

# Zero bytes payload
$client = SL::Test::Client->new(1);
$client->send_all(pack('nnn', 0, 0, 0), 6);
ok($s->readline(), '/disconnected!/');
ok($s->readline(), '/error: 0 byte payload invalid/');
