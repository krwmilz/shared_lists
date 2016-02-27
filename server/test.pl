#!/usr/bin/perl
use strict;
use warnings;

use TAP::Harness;
use Getopt::Std;

my %opts;
# -c : enable test coverage
getopts('c', \%opts);

my $harness = TAP::Harness->new({
	color => 1,
	test_args => [ $opts{c} ]
});

# Run tests
$harness->runtests(glob("t/*.t"));

if ($opts{c}) {
	print "Coverage build, running 'cover'\n";
	system("cover");
}
