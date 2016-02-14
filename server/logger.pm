package logger;
use POSIX;

sub new {
	my $class = shift;

	my $self = {};
	bless ($self, $class);

	$self->{addr} = '';
	$self->{port} = '';
	$self->{msg_type} = '';
	return $self;
}

sub set_peer_host_port {
	my ($self, $sock) = @_;
	($self->{addr}, $self->{port}) = ($sock->peerhost(), $sock->peerport());
}

sub set_msg {
	my ($self, $msg_type) = @_;

	if ($msg_type ne '') {
		$self->{msg_type} = "$msg_type: ";
	} else {
		$self->{msg_type} = '';
	}
}

sub print {
	my ($self, @args) = @_;

	my $ftime = strftime("%F %T", localtime);
	printf "%s %-15s %-5s> %s", $ftime, $self->{addr}, $self->{port}, $self->{msg_type};
	# we print potentially unsafe strings here, don't use printf
	print @args;
}

sub print_bare {
	my ($self, @args) = @_;

	my $ftime = strftime("%F %T", localtime);
	printf "%s> ", $ftime;
	printf @args;
}

1;
