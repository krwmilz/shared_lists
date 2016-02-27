use strict;
use Test;
use TestSL;

BEGIN { plan tests => 18 }

my $s = TestSL::Server->new();
my $A = TestSL::Client->new();
my $B = TestSL::Client->new();

# make A and B mutual friends
$A->friend_add($B->phnum());
$B->friend_add($A->phnum());

# A creates a new list
my $list_name = "this is a new list";
my $As_list = $A->list_add({ name => $list_name, date => 0 });

# B joins A's list
my $list = $B->list_join($As_list->{num});
ok( $list->{num}, $As_list->{num} );
ok( $list->{name}, 'this is a new list' );
ok( $list->{date}, 0 );
ok( $list->{items_complete}, 0 );
ok( $list->{items_total}, 0 );
ok( $list->{num_members}, 2 );

# B requests its lists to make sure its committed to the list
($list) = @{ $B->lists_get() };

# Verify what we get from server
for ('num', 'name', 'date') {
	ok( $As_list->{$_}, $list->{$_} );
}
