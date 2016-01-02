package test;
use strict;
use warnings;

use Errno;
use Exporter qw(import);
use IO::Socket::SSL;
use String::Random;
use Time::HiRes qw(usleep);

require "msgs.pl";
our (%msg_num, @msg_str);

our @EXPORT = qw(new_socket fail send_msg recv_msg %msg_num @msg_str check_status rand_phnum);

sub fail {
	my (undef, $file, $line) = caller;
	print "$file:$line: " . shift . "\n";
	exit 1;
}

my $string_gen = String::Random->new;
sub rand_phnum {
	return $string_gen->randpattern('nnnnnnnnnn');
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

sub send_msg {
	my ($sock, $msg_type, $msg) = @_;

	if (! exists $msg_num{$msg_type}) {
		fail "send_msg: invalid message type '$msg_type'";
	}

	my $hdr_length = 4;
	my $msg_length = length($msg);

	send_all($sock, pack("nn", $msg_num{$msg_type}, $msg_length), $hdr_length);
	send_all($sock, $msg, $msg_length);

	return $hdr_length + $msg_length;
}

sub send_all {
	my ($socket, $bytes, $bytes_total) = @_;

	my $bytes_written = $socket->syswrite($bytes);

	if (!defined $bytes_written) {
		fail "send_all: write failed: $!";
	} elsif ($bytes_written != $bytes_total) {
		fail "send_all: wrote $bytes_written instead of $bytes_total bytes";
	}

	return;
}

sub recv_msg {
	my ($sock, $expected_type) = @_;

	my $header = read_all($sock, 4);
	my ($msg_type, $msg_size) = unpack("nn", $header);

	if ($msg_type >= @msg_str) {
		fail "recv_msg: unknown message type $msg_type";
	}
	if ($msg_str[$msg_type] ne $expected_type) {
		fail "recv_msg: response type mismatch '$msg_str[$msg_type]'" .
			" != '$expected_type'";
	}

	if ($msg_size > 4096) {
		fail "recv_msg: $msg_size byte message too large";
	}
	elsif ($msg_size == 0) {
		# don't try and do another read, as a read of size 0 is EOF
		return ("", 0);
	}

	my $msg = read_all($sock, $msg_size);
	return ($msg, $msg_size);
}

sub read_all {
	my ($sock, $bytes_total) = @_;

	my $bytes_read = $sock->sysread(my $data, $bytes_total);

	if (!defined $bytes_read) {
		fail "recv_msg: read failed: $!";
	} elsif ($bytes_read == 0) {
		fail "recv_msg: read EOF on socket";
	} elsif ($bytes_read != $bytes_total) {
		fail "recv_msg: read $bytes_read instead of $bytes_total bytes";
	}

	return $data;
}

sub check_status {
	my ($msg, $expected_status) = @_;

	my $first_null = index($msg, "\0");
	if ($first_null == -1) {
		fail "check_status: no null byte found in response";
	}

	my $msg_status = substr($msg, 0, $first_null);
	my $msg_rest = substr($msg, $first_null + 1);

	if ($msg_status ne $expected_status) {
		fail "unexpected receive status '$msg_status': '$msg_rest'";
	}

	return $msg_rest;
}

1;
