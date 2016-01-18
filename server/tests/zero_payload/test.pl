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

	$A->send_msg( {} );
	my $response = $A->recv_msg('err');
	fail_msg_ne 'a missing message argument was required', $response->{reason};
}
