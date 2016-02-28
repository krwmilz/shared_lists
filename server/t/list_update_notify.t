use strict;
use Test;
use SL::Test;

BEGIN { plan tests => 14 }

my $s = SL::Test::Server->new();
my $n = SL::Test::Notify->new();

my $A = SL::Test::Client->new();
my $B = SL::Test::Client->new();
my $C = SL::Test::Client->new();

my $list = $A->list_add({ name => 'this is a new list', date => 0 });

$A->friend_add($B->phnum());
$B->friend_add($A->phnum());

$C->list_join($list->{num});

$A->list_update({ num => $list->{num}, name => 'this is an updated name' });

ok($n->readline(), "/message type 'updated_list'/");
ok($n->readline(), "/sending to 'token_.*' os 'unix'/");
ok($n->readline(), "/sending to 'token_.*' os 'unix'/");
