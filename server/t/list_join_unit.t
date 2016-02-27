use strict;
use Test;

BEGIN { plan tests => 7 }

use SL;

my $s = SL::Server->new();
my $A = SL::Client->new();

# Try joining a list that doesn't exist
my $err = $A->list_join('12345678', 'err');
ok($err, 'the client sent an unknown list number');

# Test joining a list your already in
my $list = $A->list_add({ name => 'my new test list', date => 0 });
$err = $A->list_join($list->{num}, 'err');
ok($err, 'the device is already part of this list');
