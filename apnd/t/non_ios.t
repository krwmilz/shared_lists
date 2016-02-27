use strict;
use Test;

BEGIN { plan tests => 3 }

use APND;
use JSON::XS;

my $server = APND::Server->new();
my $socket = APND::Socket->new();

my $msg = {
	msg_type => "updated_list",
	payload => { },
	devices => [
		[ "not_ios", "hex" ],
		[ "android", "some_token" ]
	]
};

my $encoded_json = encode_json($msg);
$socket->write($encoded_json);

ok($server->readline(), "/sending message type 'updated_list' to 2 device/");
ok($server->readline(), '/hex: not an ios device/');
ok($server->readline(), '/some_token: not an ios device/');

$server->kill();
