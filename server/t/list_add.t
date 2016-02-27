use strict;
use Scalar::Util qw(looks_like_number);
use Test;
use SL::Test;

BEGIN { plan tests => 10 }

my $s = SL::Test::Server->new();
my $A = SL::Test::Client->new();

# make sure normal list_add works
my $name = 'this is a new list';
my $list = $A->list_add({ name => $name, date => 0 });

ok(looks_like_number($list->{num}));
ok($list->{name}, $name);
ok($list->{num_members}, 1);
ok($list->{members}->[0], $A->phnum());

# verify a new_list request with an empty list name succeeds
$A->list_add({ name => '', date => 0 });

ok(scalar( @{ $A->lists_get() } ), 2);
