use strict;
use Test;
use SL::Test;

BEGIN { plan tests => 8 }

my $s = SL::Test::Server->new();
my $A = SL::Test::Client->new();

# Try leaving a list your not in
my $err = $A->list_leave('1234567', 'err');
ok($err, 'the client sent an unknown list number');
ok($s->readline(), "/unknown list number '.*'/");

# Try leaving the empty list
$err = $A->list_leave('', 'err');
ok($err, 'the client sent a list number that was not a number');
ok($s->readline(), "/'' is not a number/");
