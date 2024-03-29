package SL::Test::Server;
use strict;

use IPC::Open3;

sub new {
	my $class = shift;

	my $self = {};
	bless ($self, $class);

	my $perl_args = '';
	if (defined $ARGV[0] && $ARGV[0] eq '-c') {
		# Enable test coverage when -c is passed to the test
		$perl_args = '-MDevel::Cover=-silent,1';
	}

	$ENV{PATH} = "/bin:/usr/bin";
	delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };
	my $pid = open3(undef, undef, \*CHLD_ERR, "perl $perl_args -T sl -t -p 4729");

	$self->{pid} = $pid;
	$self->{CHLD_ERR} = \*CHLD_ERR;
	return $self;
}

sub readline {
	my $self = shift;
	return readline $self->{CHLD_ERR};
}

sub DESTROY {
	my $self = shift;

	kill 'TERM', $self->{pid};
	waitpid( $self->{pid}, 0 );
}

1;

package SL::Test::Client;
use strict;
use warnings;

use IO::Socket::SSL;
use JSON::XS;
use String::Random;
use Test;
use Time::HiRes qw(usleep);

require "msgs.pl";
our (%msg_num, @msg_str);

sub new {
	my $class = shift;
	my $dont_register = shift || 0;

	my $self = {};
	bless ($self, $class);

	my $socket = undef;
	while (! $socket) {
		$socket = IO::Socket::SSL->new(
			PeerHost => 'localhost',
			PeerPort => 4729,
			# certs are signed with absentmindedproductions.ca
			SSL_verifycn_name => "absentmindedproductions.ca",
		) or usleep(100 * 1000);
	}
	die "failed connect or ssl handshake: $!,$SSL_ERROR" unless ($socket);

	$self->{sock} = $socket;
	$self->{device_id} = undef;

	if ($dont_register == 0) {
		my $string_gen = String::Random->new;
		$self->{phnum} = '403' . $string_gen->randpattern('nnnnnnn');

		my $args = { phone_number => $self->{phnum}, os => 'unix' };
		$self->{device_id} = $self->device_add($args);

		$self->device_update( "token_$self->{phnum}" );
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

	# Only append "data" key if optional parameter $msg_data is defined
	my $msg_args->{data} = $msg_data if (defined $msg_data);

	# device_add is the only message type that does not require device_id as
	# a mandatory argument
	$msg_args->{device_id} = $self->{device_id} if ($msg_type ne 'device_add');

	$self->send_msg($msg_type, $msg_args);
	my $resp = $self->recv_msg($msg_type);

	# Check that the response status matches the expected status
	ok( $resp->{status}, $exp_status );

	# Return the failure reason if the response status was error
	return $resp->{reason} if ($resp->{status} eq 'err');

	# Everything looks good, return the response data
	return $resp->{data};
}

sub send_msg {
	my ($self, $msg_type, $request) = @_;

	# Request comes in as a hash ref, do this now to figure out length
	my $payload = encode_json($request);

	die "invalid message type $msg_type" unless (grep { $_ eq $msg_type } @msg_str);

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

	die "write failed: $!" if (!defined $bytes_written);
	die "wrote $bytes_written instead of $bytes_total bytes" if ($bytes_written != $bytes_total);

	return $bytes_total;
}

sub recv_msg {
	my ($self, $exp_msg_type) = @_;

	# Read header
	my $header = $self->read_all(6);
	my ($version, $msg_type, $payload_size) = unpack("nnn", $header);

	# Check some things
	die "unsupported protocol version $version" if ($version != 0);
	die "unknown message type $msg_type" if ($msg_type >= @msg_str);
	die "0 byte payload" if ($payload_size == 0);
	die "unexpected message type $msg_type" if ($msg_num{$exp_msg_type} != $msg_type);

	# Read again for payload, $payload_size > 0
	my $payload = $self->read_all($payload_size);

	# This will die if $payload is not JSON
	my $response = decode_json($payload);

	# Don't accept messages without an object root (ie array roots)
	if (ref($response) ne "HASH") {
		die "server didn't send back object root element";
	}

	return $response;
}

sub read_all {
	my ($self, $bytes_total) = @_;

	my $data;
	my $bytes_read = 0;
	while ($bytes_total > 0) {
		my $read = $self->{sock}->sysread($data, $bytes_total, $bytes_read);

		die "read failed: $!" unless (defined $read);
		die "read EOF on socket" if ($read == 0);

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

sub msg_str {
	return @msg_str;
}

1;

package SL::Test::Notify;
use strict;

use IPC::Open2;

sub new {
	my $class = shift;

	my $self = {};
	bless ($self, $class);

	my $pid = open2(\*CHLD_OUT, undef, "perl", "SL/testd.pl");

	$self->{pid} = $pid;
	$self->{chld_out} = \*CHLD_OUT;
	return $self;
}

sub readline {
	my $self = shift;
	return readline $self->{chld_out};
}

sub DESTROY {
	my $self = shift;

	kill 'TERM', $self->{pid};
	waitpid( $self->{pid}, 0 );
}

1;
