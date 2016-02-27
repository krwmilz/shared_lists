use strict;
use Test;
use TestSL;

BEGIN { plan tests => 6 }

my $s = TestSL::Server->new();
my $A = TestSL::Client->new();

# check that adding the same list twice works
my $name = 'some list thats going to be added twice';
$A->list_add({ name => $name, date => 0 });
$A->list_add({ name => $name, date => 0 });

my $num_lists = scalar(@{ $A->lists_get() });
ok( $num_lists, 2 );
# XXX: add validation this gives back 2 independent lists
