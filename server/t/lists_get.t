use strict;
use Test;
use SL::Test;

BEGIN { plan tests => 28 }

my $s = SL::Test::Server->new();
my $A = SL::Test::Client->new();

# Create 3 new lists
my @stored_lists;
for ('new list 1', 'new list 2', 'new list 3') {
	push @stored_lists, $A->list_add({ name => $_, date => 0 });
}

my $i = 0;
# Verify the information from lists_get matches what we know is true
for my $list (@{ $A->lists_get() }) {
	my $num = $list->{num};
	my $stored_list = $stored_lists[$i];

	ok( $list->{num}, $stored_list->{num} );
	ok( $list->{num_members}, $stored_list->{num_members} );
	ok( $list->{members}->[0], $A->phnum );
	ok( $list->{name}, $stored_list->{name} );
	ok( $list->{date}, $stored_list->{date} );
	ok( $list->{items_total}, 0 );
	ok( $list->{items_complete}, 0 );
	$i++;
}
ok( $i, 3 );
