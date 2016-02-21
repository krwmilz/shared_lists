package client;
use strict;
use warnings;

use Carp;
use IO::Socket::SSL;
use JSON::XS;
use Try::Tiny;
use test;

require "msgs.pl";
our (%msg_num, @msg_str);

sub new {
	my $class = shift;
	my $dont_register = shift || 0;

	my $self = {};
	bless ($self, $class);

	$self->{sock} = IO::Socket::SSL->new(
		PeerHost => 'localhost',
		PeerPort => $ENV{PORT} || 5437,
		# this is needed because PeerHost is localhost and our SSL
		# certificates are signed with absentmindedproductions.ca
		SSL_verifycn_name => "absentmindedproductions.ca",
	);
	unless ($self->{sock}) {
		die "failed connect or ssl handshake: $!,$SSL_ERROR";
	}

	$self->{device_id} = undef;

	if ($dont_register == 0) {
		$self->{phnum} = rand_phnum();

		my $args = { phone_number => $self->{phnum}, os => 'unix' };
		$self->{device_id} = $self->device_add($args);

		$self->device_update({ pushtoken_hex => "token_$self->{phnum}" }, 'ok');
	}

	return $self;
}

sub device_add {
	my ($self, $args, $status) = @_;
	return $self->communicate('device_add', $status, $args);
}

sub device_update {
	my ($self, $args, $status) = @_;
	return $self->communicate('device_update', $status, $args);
}

sub list_add {
	my ($self, $args, $status) = @_;
	return $self->communicate('list_add', $status, $args);
}

sub list_update {
	my ($self, $args, $status) = @_;
	return $self->communicate('list_update', $status, $args);
}

sub list_join {
	my ($self, $args, $status) = @_;
	return $self->communicate('list_join', $status, $args);
}

sub list_leave {
	my ($self, $args, $status) = @_;
	return $self->communicate('list_leave', $status, $args);
}

sub friend_add {
	my ($self, $args, $status) = @_;
	return $self->communicate('friend_add', $status, $args);
}

sub friend_delete {
	my ($self, $args, $status) = @_;
	return $self->communicate('friend_delete', $status, $args);
}

sub lists_get {
	my ($self, $status) = @_;
	return $self->communicate('lists_get', $status);
}

sub lists_get_other {
	my ($self, $status) = @_;
	return $self->communicate('lists_get_other', $status);
}

sub communicate {
	my ($self, $msg_type, $exp_status, $msg_data) = @_;

	# If no expected status was passed in assume 'ok'
	$exp_status = 'ok' if (! defined $exp_status);

	my $msg_args->{data} = $msg_data;

	# device_add is the only message type that does not require device_id as
	# a mandatory argument
	$msg_args->{device_id} = $self->{device_id} if ($msg_type ne 'device_add');

	$self->send_msg($msg_type, $msg_args);
	my $resp = $self->recv_msg($msg_type);

	# Check that the received status was the same as the expected status
	my $status = $resp->{status};
	confess "wrong message status '$status'" if ($status ne $exp_status);

	# Response indicated error, return the reason
	return $resp->{reason} if ($status eq 'err');

	# Everything looks good, return the response data
	return $resp->{data};
}

sub send_msg {
	my ($self, $msg_type, $request) = @_;

	# Request comes in as a hash ref, do this now to figure out length
	my $payload = encode_json($request);

	confess "invalid message type $msg_type" unless (grep { $_ eq $msg_type } @msg_str);

	my $version = 0;
	my $payload_len = length($payload);
	my $header = pack("nnn", $version, $msg_num{$msg_type}, $payload_len);

	my $sent_bytes = 0;
	$sent_bytes += $self->send_all($header, length($header));
	$sent_bytes += $self->send_all($payload, $payload_len);

	return $sent_bytes;
}

sub send_all {
	my ($self, $bytes, $bytes_total) = @_;

	my $bytes_written = $self->{sock}->syswrite($bytes);

	confess "write failed: $!" if (!defined $bytes_written);
	confess "wrote $bytes_written instead of $bytes_total bytes" if ($bytes_written != $bytes_total);

	return $bytes_total;
}

sub recv_msg {
	my ($self, $exp_msg_type) = @_;

	# Read header
	my $header = $self->read_all(6);
	my ($version, $msg_type, $payload_size) = unpack("nnn", $header);

	# Check some things
	confess "unsupported protocol version $version" if ($version != 0);
	confess "unknown message type $msg_type" if ($msg_type >= @msg_str);
	confess "0 byte payload" if ($payload_size == 0);
	confess "unexpected message type $msg_type" if ($msg_num{$exp_msg_type} != $msg_type);

	# Read again for payload, $payload_size > 0
	my $payload = $self->read_all($payload_size);

	my $response;
	try {
		$response = decode_json($payload);
	} catch {
		confess "server sent invalid json";
	};

	# Don't accept messages without an object root (ie array roots)
	if (ref($response) ne "HASH") {
		confess "server didn't send back object root element";
	}

	return $response;
}

sub read_all {
	my ($self, $bytes_total) = @_;

	my $data;
	my $bytes_read = 0;
	while ($bytes_total > 0) {
		my $read = $self->{sock}->sysread($data, $bytes_total, $bytes_read);

		confess "read failed: $!" unless (defined $read);
		confess "read EOF on socket" if ($read == 0);

		$bytes_total -= $read;
		$bytes_read += $read;
	}

	return $data;
}

sub phnum {
	my ($self) = @_;
	return $self->{phnum};
}

sub device_id {
	my ($self) = @_;
	return $self->{device_id};
}

sub set_device_id {
	my ($self, $new_id) = @_;
	$self->{device_id} = $new_id;
}

1;
