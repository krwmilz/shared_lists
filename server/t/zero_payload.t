use strict;
use Test;
use SL::Test;

BEGIN { plan tests => 24 }

# Create new device, turn off automatic device_add
my $s = SL::Test::Server->new();
my $A = SL::Test::Client->new(1);

# Send size zero payload to all message types
for ( $A->msg_str() ) {
	my $msg_good = 'a missing message argument was required';
	my $log_good = "/bad request, missing key 'device_id'/";
	if ($_ eq 'device_add') {
		$msg_good = 'the sent phone number is not a number';
		$log_good = "/phone number invalid/";
	}

	# Send empty dictionary
	$A->send_msg($_,  {} );
	my $response = $A->recv_msg($_);
	ok( $response->{reason}, $msg_good );
	ok( $s->readline(), $log_good );
}
