use strict;
use Test;
use SL::Test;

BEGIN { plan tests => 4 }

my $s = SL::Test::Server->new();
my $A = SL::Test::Client->new();

$A->device_update({ pushtoken_hex => "AD34A9EF72DC714CED" });

ok(1)
