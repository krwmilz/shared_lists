use strict;
use Test;
use SL::Test;

BEGIN { plan tests => 13 }

my $s = SL::Test::Server->new();
my $A = SL::Test::Client->new();

# Someone who is not your friend
my $err = $A->friend_delete('12345', 'err');
ok($err, 'friend sent for deletion was not a friend');
ok($s->readline(), "/tried deleting friend '.*' but they weren't a friend/");

# Non numeric friends phone number
$err = $A->friend_delete('asdf123', 'err');
ok($err, 'friends phone number is not a valid phone number');
ok($s->readline(), "/bad friends number '.*'/");

# Empty phone number
$err = $A->friend_delete('', 'err');
ok($err, 'friends phone number is not a valid phone number');
ok($s->readline(), "/bad friends number '.*'/");

# Add/delete cycle works
$A->friend_add('12345');
$A->friend_delete('12345');
