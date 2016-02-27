use strict;
use Test;
use TestSL;

BEGIN { plan tests => 4 }

my $s = TestSL::Server->new();
my $A = TestSL::Client->new();

$A->device_update({ pushtoken_hex => "AD34A9EF72DC714CED" });

ok(1)
