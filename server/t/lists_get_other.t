use strict;
use Test;
use TestSL;

BEGIN { plan tests => 13 }

# Create A and B
my $s = TestSL::Server->new();
my $A = TestSL::Client->new();
my $B = TestSL::Client->new();

# A and B become mutual friends
$A->friend_add($B->phnum());
$B->friend_add($A->phnum());

# A adds a new list
my $as_list = $A->list_add({ name => 'this is a new list that B can see', date => 0 });

# Check that B can see As list
my @other_lists = @{ $B->lists_get_other() };
ok( $other_lists[0]->{name}, $as_list->{'name'} );
ok( $other_lists[0]->{num}, $as_list->{'num'} );
ok( $other_lists[0]->{num_members}, 1 );
ok( $other_lists[0]->{members}->[0], $A->phnum() );
ok( scalar(@other_lists), 1 );
