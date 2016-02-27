use strict;
use Test;
use SL::Test;

BEGIN { plan tests => 10 }

# Test list reference counting to make sure they stay alive when needed
my $s = SL::Test::Server->new();
my $A = SL::Test::Client->new();
my $B = SL::Test::Client->new();

# A creates a new list
my $list = $A->list_add({ name => 'this list will belong to B soon enough', date => 0 });

# XXX: missing steps
# - A and B become mutual friends
# - B requests his other lists
# - B joins A's list

# B joins A's list, A leaves its own list
$B->list_join($list->{num});
$A->list_leave($list->{num});

# B verifies its still in the list
ok( scalar(@{ $B->lists_get() }), 1 );

# B also leaves the list
$B->list_leave($list->{num});
