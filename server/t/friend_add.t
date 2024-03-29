use strict;
use Test;
use SL::Test;

BEGIN { plan tests => 13 }

my $s = SL::Test::Server->new();
my $A = SL::Test::Client->new();

# Normal message
$A->friend_add('54321');

# Re-add same friend
$A->friend_add('54321');

# Non numeric phone number
my $err = $A->friend_add('123asdf', 'err');
ok($err, 'friends phone number is not a valid phone number');
ok( $s->readline(), "/bad friends number '.*'/" );

# Empty phone number
$err = $A->friend_add('', 'err');
ok($err, 'friends phone number is not a valid phone number');
ok( $s->readline(), "/bad friends number '.*'/" );

# Friending yourself
$err = $A->friend_add($A->phnum(), 'err');
ok($err, 'device cannot add itself as a friend');
ok( $s->readline(), "/device '.*' tried adding itself/" );
