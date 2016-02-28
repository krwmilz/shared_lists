use strict;
use Test;
use SL::Test;

BEGIN { plan tests => 25 }

# Test that a message greater than 65KB doesn't get sent
my $s = SL::Test::Server->new();
my $A = SL::Test::Client->new();

$A->list_add({ name => 'a' x 4000, date => 0 }) for (1..20);

# This request should be 20 * 4000 Bytes = ~80KB
my $err = $A->lists_get('err');
ok($err, 'response too large');
ok($s->readline(), "/error: 82135 byte response too large to send/");
