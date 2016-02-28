use strict;
use Test;
use SL::Test;

BEGIN { plan tests => 9 }

my $s = SL::Test::Server->new();
my $n = SL::Test::Notify->new();

my $A = SL::Test::Client->new();
my $B = SL::Test::Client->new();

$A->friend_add($B->phnum());
$B->friend_add($A->phnum());

my $list = $A->list_add({ name => 'as list', date => 0 });

# Check that notifications would have been sent
ok($n->readline(), "/message type 'friend_added_list'/");
ok($n->readline(), "/sending to 'token_.*' os 'unix'/");
