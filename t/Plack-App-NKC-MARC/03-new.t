use strict;
use warnings;

use Plack::App::NKC::MARC;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
my $obj = Plack::App::NKC::MARC->new;
isa_ok($obj, 'Plack::App::NKC::MARC');
