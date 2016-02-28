use strict;
use Test;
use SL::Test;

BEGIN { plan tests => 63 }

# Test that sending invalid device id's results in errors

my $s = SL::Test::Server->new();
# Don't register
my $A = SL::Test::Client->new(1);

my @device_ids = ('' , 'somebull$hit', 'legit');
my @good_msgs = ('the client sent a device id that was not base64',
	'the client sent a device id that was not base64',
	'the client sent an unknown device id'
);
my @good_logs = ('/bad device id/', '/bad device id/', "/unknown device 'legit'/");

for (0..2) {
	$A->set_device_id($device_ids[$_]);

	# for messages that send 2 arguments, send an empty 2nd argument
	my $err = $A->friend_add('', 'err');
	ok( $err, $good_msgs[$_] );
	ok( $s->readline(), $good_logs[$_]);

	$err = $A->friend_delete('', 'err');
	ok( $err, $good_msgs[$_] );
	ok( $s->readline(), $good_logs[$_]);

	$err = $A->list_add('', 'err');
	ok( $err, $good_msgs[$_] );
	ok( $s->readline(), $good_logs[$_]);

	$err = $A->list_join('', 'err');
	ok( $err, $good_msgs[$_] );
	ok( $s->readline(), $good_logs[$_]);

	$err = $A->list_leave('', 'err');
	ok( $err, $good_msgs[$_] );
	ok( $s->readline(), $good_logs[$_]);

	# messages that send 1 argument
	$err = $A->lists_get('err');
	ok( $err, $good_msgs[$_] );
	ok( $s->readline(), $good_logs[$_]);

	$err = $A->lists_get_other('err');
	ok( $err, $good_msgs[$_] );
	ok( $s->readline(), $good_logs[$_]);
}
