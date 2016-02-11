#!/usr/bin/perl -I../
use strict;
use warnings;
use client;
use test;

require '../msgs.pl';
our (@msg_str);

# Create new device, turn off automatic device_add
my $A = client->new(1);

# Send size zero payload to all message types
for (@msg_str) {
	$A->set_msg_type( $_ );

	my $msg_good = 'a missing message argument was required';
	if ($_ eq 'device_add') {
		$msg_good = 'the sent phone number is not a number';
	}

	# Send empty dictionary
	$A->send_msg( {} );
	my $response = $A->recv_msg('err');
	fail_msg_ne $msg_good, $response->{reason};
}
