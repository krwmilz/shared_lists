package testlib;
use strict;
use warnings;

use Exporter qw(import);
use IO::Socket;

our @EXPORT = qw(new_socket fail send_msg recv_msg);

sub fail {
	print shift;
	exit 1;
}

sub new_socket
{
	my $sock = new IO::Socket::INET(
		LocalHost => '127.0.0.1',
		PeerHost => '127.0.0.1',
		PeerPort => 5437,
		Proto => 'tcp'
	);

	die "error: socket creation failed: $!\n" unless $sock;
	return $sock;
}

sub send_msg
{
	my ($sock, $type, $contents) = @_;

	# send away
	print $sock pack("nn", $type, length($contents));
	print $sock $contents;
}

sub recv_msg
{
	my ($sock) = @_;

	# wait for response
	my ($metadata, $type, $size);
	my $bread = read($sock, $metadata, 4);
	unless (defined $bread) {
		fail "read(): $!\n";
	}
	if ($bread != 4) {
		fail "read() returned $bread instead of 4!";
	}
	unless (($type, $size) = unpack("nn", $metadata)) {
		fail "error unpacking metadata";
	}

	# XXX: do msg type upper bounds checking here
	# fail "server sent $resp_type msg instead of $type" if ($resp_type != $type);
	fail "bad message size not 0 <= $size < 1024" if ($size < 0 || $size > 1023);

	my $data;
	if ((my $bread = read($sock, $data, $size)) != $size) {
		fail "read() returned $bread instead of $size!";
	}

	return ($type, $data, $size);
}

1;
