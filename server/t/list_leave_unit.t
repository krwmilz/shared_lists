use strict;
use Test;

BEGIN { plan tests => 6 }

use SL;

my $s = SL::Server->new();
my $A = SL::Client->new();

# Try leaving a list your not in
my $err = $A->list_leave('1234567', 'err');
ok($err, 'the client sent an unknown list number');

# Try leaving the empty list
$err = $A->list_leave('', 'err');
ok($err, 'the client sent a list number that was not a number');
