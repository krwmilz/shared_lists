use strict;
use Test;
use TestSL;

BEGIN { plan tests => 12 }

my $server = TestSL::Server->new();
my $A = TestSL::Client->new();

# Constructor automatically calls device_add so no need to do it here
my $devid = $A->device_id();
my $length = length($devid);
ok($devid, 'm/^[a-zA-Z0-9+\/=]+$/');
ok($length, 43);

# Duplicate phone number
my $err = $A->device_add({ phone_number => $A->phnum, os => 'unix' }, 'err');
ok($err, 'the sent phone number already exists');

# Bad phone number
$err = $A->device_add({ phone_number => '403867530&', os => 'unix' }, 'err');
ok($err, 'the sent phone number is not a number');

# Bad operating system
$err = $A->device_add({ phone_number => 12345, os => 'bados' }, 'err');
ok($err, 'operating system not supported');

# Good operating systems
$A->device_add({ phone_number => 678910, os => 'android' });
$A->device_add({ phone_number => 231455, os => 'ios' });
