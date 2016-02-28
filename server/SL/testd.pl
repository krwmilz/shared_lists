#!/usr/bin/perl
use strict;
use warnings;
$| = 1;

use IO::Socket::UNIX;
use JSON::XS;

my $socket_path = "testd.socket";

$SIG{TERM} = sub { unlink $socket_path; exit 0 };
$SIG{INT} = sub { unlink $socket_path; exit 0 };

my $server = IO::Socket::UNIX->new(
	Type => SOCK_STREAM(),
	Local => $socket_path,
	Listen => 1,
) or die "$socket_path: couldn't create socket: $!\n";

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
