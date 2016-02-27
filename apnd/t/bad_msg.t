use strict;
use Test;

BEGIN { plan tests => 1 }

use APND;
use JSON::XS;

my $server = APND::Server->new();
my $socket = APND::Socket->new();

my $msg = {
};

my $encoded_json = encode_json($msg);
$socket->write($encoded_json);

ok($server->readline(), "/sending message type '' to 0 device/");

$server->kill();
