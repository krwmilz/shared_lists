use strict;
use Test;

BEGIN { plan tests => 10 }

use SL;

my $server = SL::Server->new();
my $A = SL::Client->new();

# Someone who is not your friend
my $err = $A->friend_delete('12345', 'err');
ok($err, 'friend sent for deletion was not a friend');

# Non numeric friends phone number
$err = $A->friend_delete('asdf123', 'err');
ok($err, 'friends phone number is not a valid phone number');

# Empty phone number
$err = $A->friend_delete('', 'err');
ok($err, 'friends phone number is not a valid phone number');

# Add/delete cycle works
$A->friend_add('12345');
$A->friend_delete('12345');
