use strict;
use Test;
use TestSL;

BEGIN { plan tests => 19 }

my $s = TestSL::Server->new();
my $A = TestSL::Client->new();

# Test sending a request with no 'num' key
my $err = $A->list_update({ name => 'some name' }, 'err');
ok( $err, 'the client did not send a list number' );

# Try and update a list that doesn't exist
$err = $A->list_update({ num => 123456, name => 'some name' }, 'err');
ok( $err, 'the client sent an unknown list number' );

# All checks after this require a valid list, create one now
my $list = $A->list_add({ name => 'this is a new list', date => 0 });

# Update only the list name first
$A->list_update({ num => $list->{num}, name => 'this is an updated name' });

# Verify the name change persisted
my @lists = @{ $A->lists_get() };
ok( $lists[0]->{name},  'this is an updated name' ) ;
ok( $lists[0]->{date}, 0 );

# Update only the date
$A->list_update({ num => $list->{num}, date => 12345 });

# Verify the date change persisted
@lists = @{ $A->lists_get() };
ok( $lists[0]->{name}, 'this is an updated name' );
ok( $lists[0]->{date}, 12345 );

# Now update both the name and date
$A->list_update({ num => $list->{num}, date => 54321, name => 'updated again' });

@lists = @{ $A->lists_get() };
ok( $lists[0]->{name}, 'updated again' );
ok( $lists[0]->{date}, 54321 );
