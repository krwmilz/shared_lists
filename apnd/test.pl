use strict;
use warnings;

use TAP::Harness;

my $harness = TAP::Harness->new({});
$harness->runtests(glob("t/*.t"));
