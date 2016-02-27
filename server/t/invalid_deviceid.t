use strict;
use Test;
use TestSL;

BEGIN { plan tests => 42 }

# Test that sending invalid device id's results in errors
my $server = TestSL::Server->new();

# Don't register
my $A = TestSL::Client->new(1);

my @device_ids = ('' , 'somebull$hit', 'legit');
my @good_msgs = ('the client sent a device id that was not base64',
	'the client sent a device id that was not base64',
	'the client sent an unknown device id'
);

for (0..2) {
	$A->set_device_id($device_ids[$_]);

	# for messages that send 2 arguments, send an empty 2nd argument
	my $err = $A->friend_add('', 'err');
	ok( $err, $good_msgs[$_] );

	$err = $A->friend_delete('', 'err');
	ok( $err, $good_msgs[$_] );

	$err = $A->list_add('', 'err');
	ok( $err, $good_msgs[$_] );

	$err = $A->list_join('', 'err');
	ok( $good_msgs[$_], $err );

	$err = $A->list_leave('', 'err');
	ok( $good_msgs[$_], $err );

	# messages that send 1 argument
	$err = $A->lists_get('err');
	ok( $good_msgs[$_], $err );

	$err = $A->lists_get_other('err');
	ok( $good_msgs[$_], $err );
}
