use strict;
use Test;

BEGIN { plan tests => 4 }

use SL;

my $server = SL::Server->new();
my $A = SL::Client->new();

$A->device_update({ pushtoken_hex => "AD34A9EF72DC714CED" });

ok(1)
