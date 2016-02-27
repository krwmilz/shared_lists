use strict;
use Test;

BEGIN { plan tests => 14 }

use SL;

# XXX: Test is broken
# - for some reason sending more than 5 list_add's in a row screws something up
# - lists_get() also seems to choke sometimes
# - causes unknown

# Test that large responses > 16384 bytes work as the underlying ssl layer can
# only handle that much data at a time
my $s = SL::Server->new();

my $A = SL::Client->new();
$A->list_add({ name => "$_" x 1000, date => 0}) for (1..5);

# The response to this lists_get request clocks in at ~24 KB
my $count = 0;
for my $list (@{ $A->lists_get() }) {
	$count += 1;
	ok("$count" x 1000, $list->{name});
}

ok($count, 5);
