use strict;
use warnings;

use TAP::Harness;
use Getopt::Std;

my %args;
getopt("c", \%args);

my $harness = TAP::Harness->new({ color => 1 });
$harness->runtests(glob("t/*.t"));
