package test;
use strict;
use warnings;

use Exporter qw(import);
use IO::Socket;

require "msgs.pl";
our (%msg_num, @msg_str, @msg_func, $protocol_ver);

our @EXPORT = qw(new_socket fail send_msg recv_msg %msg_num @msg_str);

sub fail {
	print shift . "\n";
	exit 1;
}

sub new_socket
{
	if (! defined $ENV{PORT}) {
		fail "$0: error, test needs PORT environment variable set";
		exit 1;
	}

	my $sock = new IO::Socket::INET(
		LocalHost => '127.0.0.1',
		PeerHost => '127.0.0.1',
		PeerPort => $ENV{PORT},
		Proto => 'tcp'
	);

	die "error: new socket: $!\n" unless $sock;
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
	fail "bad message size not 0 <= $size < 1024" if ($size < 0 || $size > 1023);

	my $data;
	if ((my $bread = read($sock, $data, $size)) != $size) {
		fail "read() returned $bread instead of $size!";
	}

	# caller should validate this is the expected type
	return ($type, $data, $size);
}

1;
