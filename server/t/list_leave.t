use strict;
use Test;
use TestSL;

BEGIN { plan tests => 8 }

my $s = TestSL::Server->new();
my $A = TestSL::Client->new();

my $list = $A->list_add({ name => 'this list was made for leaving', date => 0 });
$A->list_leave($list->{num});

# verify we don't get this list back when requesting all lists
ok( scalar( @{ $A->lists_get() } ), 0 );
ok( scalar(@{ $A->lists_get_other() }), 0 );
