use strict;
use Test;
use TestSL;

BEGIN { plan tests => 5 }

my $s = TestSL::Server->new();
my $A = TestSL::Client->new();

# Create a new list with a name composed of 3 valid Unicode characters
# - a left double quotation mark and
# - ae sorta character thing but where they touch
# - face with medical mask
$A->list_add({ name => "\xE2\x80\x9C \xC3\xA6 \xF0\x9F\x98\xB8", date => 0 });
my ($list) = @{ $A->lists_get() };

# Check the list name we get back hasn't been mangled in the round trip
ok( "\xE2\x80\x9C \xC3\xA6 \xF0\x9F\x98\xB8", $list->{name} );
