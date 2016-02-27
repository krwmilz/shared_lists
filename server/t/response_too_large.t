use strict;
use Test;
use TestSL;

BEGIN { plan tests => 24 }

# Test that a message greater than 65KB doesn't get sent
my $s = TestSL::Server->new();
my $A = TestSL::Client->new();

$A->list_add({ name => 'a' x 4000, date => 0 }) for (1..20);

# This request should be 20 * 4000 Bytes = ~80KB
my $err = $A->lists_get('err');
ok($err, 'response too large');