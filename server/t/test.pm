package test;
use strict;
use warnings;

use Carp;
use Exporter qw(import);
use String::Random;

our @EXPORT = qw(rand_phnum fail fail_msg_ne fail_num_ne);

my $string_gen = String::Random->new;
sub rand_phnum {
	return '403' . $string_gen->randpattern('nnnnnnn');
}

sub fail {
	confess shift;
}

sub fail_msg_ne {
	my ($arg1, $arg2) = @_;
	return if ($arg1 eq $arg2);

	confess "expected string '$arg1' but got '$arg2'";
}

sub fail_num_ne {
	my ($msg, $arg1, $arg2) = @_;
	return if ($arg1 == $arg2);

	confess "$msg $arg1 != $arg2";
}

1;
