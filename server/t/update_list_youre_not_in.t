use strict;
use Test;
use TestSL;

BEGIN { plan tests => 7 }

my $s = TestSL::Server->new();

# Create A and B
my $A = TestSL::Client->new();
my $B = TestSL::Client->new();

# A adds a new list
my $list = $A->list_add({ name => 'this is a new list for a', date => 0 });

# B tries to update A's list without joining it first
my $request = { num => $list->{num}, name => 'some new name', date => 1 };
my $err = $B->list_update($request, 'err');
ok($err, 'client tried to update a list it was not in');
