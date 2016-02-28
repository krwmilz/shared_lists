use strict;
use Test;
use SL::Test;

BEGIN { plan tests => 9 }

my $s = SL::Test::Server->new();
my $A = SL::Test::Client->new();

# Try joining a list that doesn't exist
my $err = $A->list_join('12345678', 'err');
ok($err, 'the client sent an unknown list number');
ok($s->readline(), "/unknown list number '.*'/");

# Test joining a list your already in
my $list = $A->list_add({ name => 'my new test list', date => 0 });
$err = $A->list_join($list->{num}, 'err');
ok($err, 'the device is already part of this list');
ok($s->readline(), "/tried to create a duplicate list member entry for device '.*' and list '.*'/");
