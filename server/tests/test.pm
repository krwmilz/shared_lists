package test;
use strict;
use warnings;

use Exporter qw(import);
use String::Random;

our @EXPORT = qw(rand_phnum fail fail_msg_ne fail_num_ne);

my $string_gen = String::Random->new;
sub rand_phnum {
	return '1403' . $string_gen->randpattern('nnnnnnn');
}

sub fail {
	my $msg = shift;

	my (undef, $file, $line) = caller;
	print "$file:$line: $msg\n";
	exit 1;
}

sub fail_msg_ne {
	my ($arg1, $arg2) = @_;
	return if ($arg1 eq $arg2);

	my (undef, $file, $line) = caller;
	print "$file:$line: expected string '$arg1' but got '$arg2'\n";
	exit 1;
}

sub fail_num_ne {
	my ($msg, $arg1, $arg2) = @_;
	return if ($arg1 == $arg2);

	my (undef, $file, $line) = caller;
	print "$file:$line: $msg $arg1 != $arg2\n";
	exit 1;
}

1;
