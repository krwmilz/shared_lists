use strict;
use Test;
use SL::Test;

BEGIN { plan tests => 19 }

# this test makes sure that when 2 friends of yours are in the same list that
# your not in, that the list doesn't show up twice in your list_get_other
# request.
my $s = SL::Test::Server->new();

my $A = SL::Test::Client->new();
my $B = SL::Test::Client->new();
my $C = SL::Test::Client->new();

# A and B are mutual friends
$A->friend_add($B->phnum());
$B->friend_add($A->phnum());

# A and C are also mutual friends
$A->friend_add($C->phnum());
$C->friend_add($A->phnum());

# B and C need to be in the same list
my $list = $B->list_add({ name => 'this is Bs new list', date => 0 });
$C->list_join($list->{num});

# A makes sure he got a single list
my @other = @{ $A->lists_get_other() };
ok( $other[0]->{num_members}, 2 );
ok( $other[0]->{num}, $list->{num} );
ok( scalar(@other), 1 );
ok( ! grep {$_ eq $A->phnum()} @{$other[0]->{members}} );
ok( grep {$_ eq $B->phnum()} @{$other[0]->{members}} );
ok( grep {$_ eq $C->phnum()} @{$other[0]->{members}} );
