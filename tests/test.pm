package test;
use strict;
use warnings;

use Errno;
use Exporter qw(import);
use IO::Socket qw(SHUT_RDWR);
use Time::HiRes qw(usleep);

require "msgs.pl";
our (%msg_num, @msg_str);

our @EXPORT = qw(new_socket fail send_msg recv_msg %msg_num @msg_str SHUT_RDWR);

sub fail {
	print "$ENV{TEST_DIR}/$0: " . shift . "\n";
	exit 1;
}

sub new_socket
{
	if (! defined $ENV{PORT}) {
		fail "$0: error, test needs PORT environment variable set";
		exit 1;
	}

	my $sock = undef;
	my $i = 0;
	while (! $sock) {
		$sock = new IO::Socket::INET(
			LocalHost => '127.0.0.1',
			PeerHost => '127.0.0.1',
			PeerPort => $ENV{PORT},
			Proto => 'tcp',
		);

		if ($!{ECONNREFUSED}) {
			# print "$i: connection refused, retrying\n";
			$i++;
			usleep(50 * 1000);
		}
		else {
			die "error: new socket: $!\n" unless $sock;
		}
	}

	return $sock;
}

sub send_msg
{
	my ($sock, $type_str, $contents) = @_;

	if (! exists $msg_num{$type_str}) {
		fail "$0: send_msg: invalid msg type '$type_str'";
	}

	# send away
	print $sock pack("nn", $msg_num{$type_str}, length($contents));
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

	if ($type < 0 || $type >= @msg_str) {
		fail "$0: recv_msg: invalid msg num '$type'";
	}
	fail "bad message size not 0 <= $size < 1024" if ($size < 0 || $size > 1023);

	my $data;
	if ((my $bread = read($sock, $data, $size)) != $size) {
		fail "read() returned $bread instead of $size!";
	}

	# caller should validate this is the expected type
	return ($msg_str[$type], $data, $size);
}

1;
