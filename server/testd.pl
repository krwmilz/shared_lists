#!/usr/bin/perl
use warnings;
use strict;
$| = 1;

use Data::Dumper;
use IO::Socket::UNIX;
use JSON::XS;

my $socket_path = "../testd.socket";

my $server = IO::Socket::UNIX->new(
	Type => SOCK_STREAM(),
	Local => $socket_path,
	Listen => 1,
);
unless ($server) {
	print "error: couldn't create socket: $!\n";
	exit 1;
}

$SIG{INT} = \&unlink_socket;
$SIG{TERM} = \&unlink_socket;

sub unlink_socket {
	unlink $socket_path;
}

while (my $client = $server->accept()) {
	$client->read(my $data, 4096);
	my $notify = decode_json($data);

	my $num_devices = @{ $notify->{devices} };
	next if ($num_devices == 0);

	print "testd: message type '$notify->{msg_type}'\n";
	# print "testd: payload is '" . Dumper($notify->{payload}) . "'\n";

	for (@{ $notify->{devices} }) {
		#print Dumper($_);
		my ($os, $push_token) = @$_;
		print "testd: sending to '$push_token' os '$os'\n";
	}
}
