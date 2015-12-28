package test;
use strict;
use warnings;

use Errno;
use Exporter qw(import);
use IO::Socket::SSL;
use Time::HiRes qw(usleep);

require "msgs.pl";
our (%msg_num, @msg_str);

our @EXPORT = qw(new_socket fail send_msg recv_msg %msg_num @msg_str SHUT_RDWR);

sub fail {
	my (undef, $file, $line) = caller;
	print "$file:$line: " . shift . "\n";
	exit 1;
}

sub new_socket
{
	if (! defined $ENV{PORT}) {
		fail "$0: error, test needs PORT environment variable set";
		exit 1;
	}

	my $sock = undef;
	my $timeout = time + 5;
	while (1) {
		$sock = new IO::Socket::SSL->new(
			PeerHost => 'localhost',
			PeerPort => $ENV{PORT},
			# this is needed because PeerHost is localhost and our
			# SSL certificates are signed with amp.ca
			SSL_verifycn_name => "absentmindedproductions.ca",
		);

		if ($!{ECONNREFUSED}) {
			if (time > $timeout) {
				fail "server not ready after 5 seconds";
			}
			usleep(100 * 1000);
			next;
		}

		last;
	}

	unless ($sock) {
		die "failed connect or ssl handshake: $!,$SSL_ERROR";
	}

	return $sock;
}

sub send_msg
{
	my ($sock, $type_str, $msg) = @_;

	if (! exists $msg_num{$type_str}) {
		fail "$0: send_msg: invalid msg type '$type_str'";
	}

	# send away
	my ($n, $msg_len) = (0, length($msg));
	$n += $sock->syswrite(pack("nn", $msg_num{$type_str}, $msg_len));
	$n += $sock->syswrite($msg);

	if ($n != ($msg_len + 4)) {
		fail "$0: send_msg: tried to send $msg_len bytes, but sent $n\n";
	}
}

sub recv_msg
{
	my ($sock) = @_;

	# wait for response
	my ($metadata, $type, $size);
	my $bread = $sock->sysread($metadata, 4);
	unless (defined $bread) {
		fail "read(): $!\n";
	}
	if ($bread != 4) {
		fail "read() returned $bread instead of 4!";
	}
	unless (($type, $size) = unpack("nn", $metadata)) {
		fail "error unpacking metadata";
	}

	if ($type >= @msg_str) {
		fail "$0: recv_msg: invalid msg num '$type'";
	}

	fail "bad message size not $size < 1024" if ($size > 1023);
	return ($msg_str[$type], undef, 0) if ($size == 0);

	my $data;
	if ((my $bread = $sock->sysread($data, $size)) != $size) {
		fail "read() returned $bread instead of $size!";
	}

	# caller should validate this is the expected type
	return ($msg_str[$type], $data, $size);
}

1;
