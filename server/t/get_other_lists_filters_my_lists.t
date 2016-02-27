use strict;
use Test;
use TestSL;

BEGIN { plan tests => 11 }

# Check that when your mutual friends are in your own lists that you don't get
# your own lists back when doing a lists_get_other request
my $server = TestSL::Server->new();

# Create A and B
my $A = TestSL::Client->new();
my $B = TestSL::Client->new();

# B adds a new list
$B->list_add({ name => 'bs new list', date => 0 });

# A and B become mutual friends
$A->friend_add($B->phnum());
$B->friend_add($A->phnum());

# A adds a new list, B joins A's new list
my $list = $A->list_add({ name => 'as new list', date => 0 });
$B->list_join($list->{num});

# A should only see B's list that it never joined
my $other = $A->lists_get_other();
ok(scalar(@$other), 1);
