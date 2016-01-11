package client;
use strict;
use warnings;

use Data::Dumper;
use Errno;
use IO::Socket::SSL;
use Time::HiRes qw(usleep);
use test;

require "msgs.pl";
our (%msg_num, @msg_str);

sub new {
	my $class = shift;
	my $dont_register = shift || 0;

	my $self = {};
	bless ($self, $class);

	$self->{sock} = undef;
	my $timeout = time + 5;
	while (1) {
		$self->{sock} = IO::Socket::SSL->new(
			PeerHost => 'localhost',
			PeerPort => $ENV{PORT} || 5437,
			# this is needed because PeerHost is localhost and our
			# SSL certificates are signed with amp.ca
			SSL_verifycn_name => "absentmindedproductions.ca",
		);

		if ($!{ECONNREFUSED}) {
			if (time > $timeout) {
				fail "server not ready after 5 seconds";
			}
			usleep(50 * 1000);
			next;
		}

		last;
	}

	unless ($self->{sock}) {
		die "failed connect or ssl handshake: $!,$SSL_ERROR";
	}

	# make sure we don't try and use this without setting it
	$self->{device_id} = undef;

	# By default register this device immediately
	if ($dont_register == 0) {
		$self->device_add(rand_phnum());
	}

	return $self;
}

sub list_add {
	my $self = shift;
	my $name = shift;
	my $status = shift || 'ok';

	my $list_data = communicate($self, 'list_add', $status, $name);

	# if we made it this far we know that $status is correct
	return if ($status eq 'err');

	save_list($self, $list_data);
}

sub list_join {
	my $self = shift;
	my $list_id = shift;
	my $status = shift || 'ok';

	my $list_data = communicate($self, 'list_join', $status, $list_id);
}

sub list_leave {
	my $self = shift;
	my $id = shift;
	my $status = shift || 'ok';

	my $list_data = communicate($self, 'list_leave', $status, $id);
}

sub save_list {
	my $self = shift;
	my $list_data = shift;

	my ($id, $name, @members) = split("\0", $list_data);
	my $list = {
		id => $id,
		name => $name,
		members => \@members,
		num_members => scalar(@members),
	};
	push @{$self->{lists}}, $list;
}

sub friend_add {
	my $self = shift;
	my $friend = shift;
	my $status = shift || 'ok';

	communicate($self, 'friend_add', $status, $friend);
}

sub friend_delete {
	my $self = shift;
	my $friend = shift;
	my $status = shift || 'ok';

	communicate($self, 'friend_delete', $status, $friend);
}

sub lists_get {
	my $self = shift;
	my $status = shift || 'ok';

	my $list_data = communicate($self, 'lists_get', $status);
	my @lists;

	for (split("\n", $list_data)) {
		my ($id, $name, $num, @members) = split("\0", $_);
		# fail "bad list" unless ($id && $name && @members != 0);

		my %tmp = (
			id => $id,
			name => $name,
			num => $num,
			members => \@members,
			num_members => scalar(@members),
		);
		push @lists, \%tmp;
	}
	return @lists;
}

sub lists_get_other {
	my $self = shift;
	my $status = shift || 'ok';

	my $list_data = communicate($self, 'lists_get_other', $status);
	my @lists;

	for (split("\n", $list_data)) {
		my ($id, $name, @members) = split("\0", $_);
		# fail "bad other list" unless ($id && $name && @members != 0);

		my %tmp = (
			id => $id,
			name => $name,
			members => \@members,
			num_members => scalar(@members)
		);
		push @lists, \%tmp;
	}
	return @lists;
}

sub device_add {
	my $self = shift;
	my $phone_number = shift || '4038675309';
	my $os = shift || 'unix';
	my $exp_status = shift || 'ok';

	# always reset error messages to guard against stale state
	$self->{err_msg} = undef;
	$self->{msg_type} = $msg_num{'device_add'};

	send_msg($self, "$phone_number\0$os");
	my $msg = recv_msg($self);

	my ($status, $device_id) = parse_status($self, $msg);
	fail "wrong message status '$status'" if ($status ne $exp_status);

	$self->{phnum} = $phone_number;
	$self->{device_id} = $device_id;
}

sub communicate {
	my ($self, $msg_type, $exp_status, @msg_args) = @_;

	# always reset error messages to guard against stale state
	$self->{err_msg} = undef;
	$self->{msg_type} = $msg_num{$msg_type};

	# prepend device id to @msg_args array
	unshift @msg_args, $self->{device_id};

	send_msg($self, join("\0", @msg_args));
	my $msg = recv_msg($self);

	my ($status, $payload) = parse_status($self, $msg);
	fail "wrong message status '$status'" if ($status ne $exp_status);

	return $payload;
}

sub parse_status {
	my ($self, $msg) = @_;

	my $first_null = index($msg, "\0");
	fail "no null byte found in response" if ($first_null == -1);

	my $msg_status = substr($msg, 0, $first_null);
	my $msg_rest = substr($msg, $first_null + 1);

	# if this is an error message keep track of it right now
	$self->{err_msg} = $msg_rest if ($msg_status eq 'err');

	return ($msg_status, $msg_rest);
}

sub send_msg {
	my ($self, $payload) = @_;

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
	my ($self) = @_;

	# read header part first
	my $header = read_all($self, 6);
	my ($version, $msg_type, $payload_size) = unpack("nnn", $header);

	fail "unsupported protocol version $version" if ($version != 0);
	fail "unknown message type $msg_type" if ($msg_type >= @msg_str);
	fail "$payload_size byte message too large" if ($payload_size > 4096);
	fail "unexpected message type $self->{msg_type}" if ($self->{msg_type} != $msg_type);

	# don't try a read_all() of size 0
	return '' if ($payload_size == 0);

	my $payload = read_all($self, $payload_size);
	return $payload;
}

sub read_all {
	my ($self, $bytes_left) = @_;

	my $data;
	while ($bytes_left > 0) {
		my $bytes_read = $self->{sock}->sysread(my $tmp, $bytes_left);

		fail "read failed: $!" unless (defined $bytes_read);
		fail "read EOF on socket" if ($bytes_read == 0);

		$data .= $tmp;
		$bytes_left -= $bytes_read;
	}

	return $data;
}

sub num_lists {
	my $self = shift;
	return scalar(@{$self->{lists}});
}

sub lists {
	my $self = shift;
	my $i = shift;

	my $num_lists = scalar(@{$self->{lists}});
	fail "tried accessing out of bounds index $i" if ($i > $num_lists);

	return $self->{lists}[$i];
}

sub lists_all {
	my $self = shift;
	return $self->{lists};
}

sub phnum {
	my $self = shift;
	return $self->{phnum};
}

sub device_id {
	my $self = shift;
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
