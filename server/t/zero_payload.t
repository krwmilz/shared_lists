use strict;
use Test;

BEGIN { plan tests => 12 }

use SL;

# Create new device, turn off automatic device_add
my $s = SL::Server->new();
my $A = SL::Client->new(1);

# Send size zero payload to all message types
for ( $A->msg_str() ) {
	my $msg_good = 'a missing message argument was required';
	if ($_ eq 'device_add') {
		$msg_good = 'the sent phone number is not a number';
	}

	# Send empty dictionary
	$A->send_msg($_,  {} );
	my $response = $A->recv_msg($_);
	ok( $response->{reason}, $msg_good );
}
