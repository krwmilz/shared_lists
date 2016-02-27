use strict;
use Test;

BEGIN { plan tests => 19 }

use SL;

my $server = SL::Server->new();
my $A = SL::Client->new();
my $B = SL::Client->new();

# A and B are mutual friends
$A->friend_add($B->phnum());
$B->friend_add($A->phnum());

# A creates 2 lists
my $As_first_list = $A->list_add({ name => "this is a's first list", date => 0 });
$A->list_add({ name => "this is a's second list", date => 0 });
# B creates 1 list
$B->list_add({ name => "this is b's first list", date => 0});

# B joins A's first list
$B->list_join($As_first_list->{num});

# A deletes B's friendship
$A->friend_delete($B->phnum());

# Check that:
# - A and B are both in A's first list
# - B can't see A's other list
# - A can't see B's other list
ok(scalar @{ $A->lists_get_other() }, 0);
ok(scalar @{ $B->lists_get_other() }, 0);

ok(scalar @{ $A->lists_get() }, 2);
ok(scalar @{ $B->lists_get() }, 2);
