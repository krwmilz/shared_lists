use strict;
use warnings;

use TAP::Harness;

my $harness = TAP::Harness->new({});

my @test_files = ("t/non_ios.t", "t/bad_msg.t");
$harness->runtests(@test_files);
