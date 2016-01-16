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
	$A->set_msg_type($_);
	$A->send_msg('');
	my $response = $A->recv_msg();

	my ($status, $err_str) = split("\0", $response, 2);
	fail "unexpected status '$status'" if ($status ne 'err');

	# Depending on the number of expected arguments, an empty message can be
	# either the wrong number of arguments (because no '\0' was sent) or an
	# unknown device id (for messages expecting 1 argument)
	my $good1 = 'the wrong number of message arguments were sent';
	my $good2 = 'the client sent an unknown device id';

	next if ($err_str eq $good1 || $err_str eq $good2);

	fail "expected either '$good1' or '$good2', instead got '$err_str'";
}
