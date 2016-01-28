package client;
use strict;
use warnings;

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

	# Register this device immediately by default
	if ($dont_register == 0) {
		$self->device_add({ phone_number => rand_phnum(), os => 'unix' });
	}

	return $self;
}

sub device_update {
	my $self = shift;
	my $msg_args = shift;
	my $status = shift || 'ok';

	my $response = communicate($self, 'device_update', $status, $msg_args);
}

sub list_add {
	my $self = shift;
	my $list = {
		name => shift,
		date => 0
	};
	my $status = shift || 'ok';

	my $response = communicate($self, 'list_add', $status, { list => $list });
	return if ($status eq 'err');

	push @{$self->{lists}}, $response->{list};
}

sub list_update {
	my $self = shift;
	my $list_ref = shift;
	my $status = shift || 'ok';

	my $list_data = communicate($self, 'list_update', $status, { list => $list_ref });
	return if ($status eq 'err');
}

sub list_join {
	my $self = shift;
	my $msg_args = {
		list_num => shift,
	};
	my $status = shift || 'ok';

	my $list_data = communicate($self, 'list_join', $status, $msg_args);
}

sub list_leave {
	my $self = shift;
	my $msg_args = {
		list_num => shift,
	};
	my $status = shift || 'ok';

	my $list_data = communicate($self, 'list_leave', $status, $msg_args);
}

sub friend_add {
	my $self = shift;
	my $msg_args = {
		friend_phnum => shift,
	};
	my $status = shift || 'ok';

	communicate($self, 'friend_add', $status, $msg_args);
}

sub friend_delete {
	my $self = shift;
	my $msg_args = {
		friend_phnum => shift,
	};
	my $status = shift || 'ok';

	communicate($self, 'friend_delete', $status, $msg_args);
}

sub lists_get {
	my $self = shift;
	my $status = shift || 'ok';

	my $response = communicate($self, 'lists_get', $status);
	return if ($response->{status} eq 'err');

	return @{ $response->{lists} };
}

sub lists_get_other {
	my $self = shift;
	my $status = shift || 'ok';

	my $response = communicate($self, 'lists_get_other', $status);
	return if ($response->{status} eq 'err');

	return @{ $response->{other_lists} };
}

sub device_add {
	my $self = shift;
	my $msg_args = shift;
	my $exp_status = shift || 'ok';

	# Reset error messages to guard against stale state
	$self->{err_msg} = undef;
	$self->{msg_type} = $msg_num{'device_add'};

	send_msg($self, $msg_args);
	my $response = recv_msg($self, $exp_status);

	if ($response->{status} eq 'ok') {
		$self->{phnum} = $msg_args->{phone_number};
		$self->{device_id} = $response->{device_id};
	}
}

sub communicate {
	my ($self, $msg_type, $exp_status, $msg_args) = @_;

	# Reset error message so it doesn't get reused
	$self->{err_msg} = undef;
	$self->{msg_type} = $msg_num{$msg_type};

	# Add device id to message arguments
	$msg_args->{device_id} = $self->{device_id};

	send_msg($self, $msg_args);
	return recv_msg($self, $exp_status);
}

sub send_msg {
	my ($self, $request) = @_;

	# Request comes in as a hash ref, do this now to figure out length
	my $payload = encode_json($request);

	my $msg_type = $self->{msg_type};
	fail "invalid message type $msg_type" if ($msg_type > @msg_str);

	my $version = 0;
	my $payload_len = length($payload);
	my $header = pack("nnn", $version, $msg_type, $payload_len);

	my $sent_bytes = 0;
	$sent_bytes += send_all($self, $header, length($header));
	$sent_bytes += send_all($self, $payload, $payload_len);

	return $sent_bytes;
}

sub send_all {
	my ($self, $bytes, $bytes_total) = @_;

	my $bytes_written = $self->{sock}->syswrite($bytes);

	fail "write failed: $!" if (!defined $bytes_written);
	fail "wrote $bytes_written instead of $bytes_total bytes" if ($bytes_written != $bytes_total);

	return $bytes_total;
}

sub recv_msg {
	my ($self, $exp_status) = @_;

	# Read header
	my $header = read_all($self, 6);
	my ($version, $msg_type, $payload_size) = unpack("nnn", $header);

	# Check some things
	fail "unsupported protocol version $version" if ($version != 0);
	fail "unknown message type $msg_type" if ($msg_type >= @msg_str);
	fail "0 byte payload" if ($payload_size == 0);
	fail "unexpected message type $self->{msg_type}" if ($self->{msg_type} != $msg_type);

	# Read again for payload, $payload_size > 0
	my $payload = read_all($self, $payload_size);

	try {
		my $response = decode_json($payload);

		if (ref($response) ne "HASH") {
			fail "server didn't send back object root element";
		}

		my $status = $response->{status};
		fail "wrong message status '$status'" if ($status ne $exp_status);
		$self->{err_msg} = $response->{reason} if ($status eq 'err');

		return $response;
	} catch {
		fail "server sent invalid json";
	}
}

sub read_all {
	my ($self, $bytes_total) = @_;

	my $data;
	my $bytes_read = 0;
	while ($bytes_total > 0) {
		my $read = $self->{sock}->sysread($data, $bytes_total, $bytes_read);

		fail "read failed: $!" unless (defined $read);
		fail "read EOF on socket" if ($read == 0);

		$bytes_total -= $read;
		$bytes_read += $read;
	}

	return $data;
}

sub num_lists {
	my ($self) = @_;
	return scalar(@{$self->{lists}});
}

sub lists {
	my ($self, $i) = @_;
	return $self->{lists}[$i];
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

sub set_msg_type {
	my ($self, $msg_num) = @_;
	$self->{msg_type} = $msg_num{$msg_num};
}

sub get_error {
	my $self = shift;
	return $self->{err_msg};
}

1;
