use strict;
use Test;
use TestSL;

BEGIN { plan tests => 10 }

my $s = TestSL::Server->new();
my $A = TestSL::Client->new();

# Normal message
$A->friend_add('54321');

# Re-add same friend
$A->friend_add('54321');

# Non numeric phone number
my $err = $A->friend_add('123asdf', 'err');
ok($err, 'friends phone number is not a valid phone number');

# Empty phone number
$err = $A->friend_add('', 'err');
ok($err, 'friends phone number is not a valid phone number');

# Friending yourself
$err = $A->friend_add($A->phnum(), 'err');
ok($err, 'device cannot add itself as a friend');
