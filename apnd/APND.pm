package APND::Server;
use strict;

use IPC::Open3;

sub new {
	my $class = shift;

	my $self = {};
	bless ($self, $class);

	my $socket_path = "apnd_test.socket";

	my $pid = open3(undef, undef, \*CHLD_ERR, "apnd", "-p", $socket_path);

	$self->{pid} = $pid;
	$self->{CHLD_ERR} = \*CHLD_ERR;
	return $self;
}

sub readline {
	my $self = shift;

	return readline $self->{CHLD_ERR};
}

sub kill {
	my $self = shift;

	kill 'TERM', $self->{pid};
	waitpid( $self->{pid}, 0 );
}

1;

package APND::Socket;
use strict;

use IO::Socket::UNIX;

sub new {
	my $class = shift;

	my $self = {};
	bless ($self, $class);

	my $socket_path = "apnd_test.socket";

	my $socket = undef;
	my $i = 0;
	while (! $socket) {
		$socket = IO::Socket::UNIX->new(
			Type => SOCK_STREAM(),
			Peer => $socket_path
		);
		$i++;
	}
	die "$socket_path: connect failed: $!\n" unless ($socket);

	print STDERR "looped $i times\n";

	$self->{socket} = $socket;
	return $self;
}

sub write {
	my ($self, $data) = @_;
	$self->{socket}->syswrite($data);
}

1;
