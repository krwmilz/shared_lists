use strict;
use Test;
use TestSL;

BEGIN { plan tests => 7 }

# Send a leave_list message that contains a valid list id but the requesting
# device is not currently a member of.
my $server = TestSL::Server->new();

my $A = TestSL::Client->new();
my $B = TestSL::Client->new();

my $list = $A->list_add({ name => 'only a can see this list', date => 0 });

# Who knows how B got this list id, but he did
my $err = $B->list_leave($list->{num}, 'err');
ok($err, 'the client was not a member of the list');
