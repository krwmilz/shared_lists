use strict;
use Test;
use TestSL;

BEGIN { plan tests => 44 }

# Test that large responses > 16384 bytes work as the underlying ssl layer can
# only handle that much data at a time
my $s = TestSL::Server->new();
my $A = TestSL::Client->new();

$A->list_add({ name => "$_" x 1000, date => 0}) for (1..20);

my $count = 0;
for my $list (@{ $A->lists_get() }) {
	$count += 1;
	ok("$count" x 1000, $list->{name});
}

ok($count, 20);
