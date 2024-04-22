use strict;
use warnings;

use Plack::App::NKC::MARC::Utils;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Plack::App::NKC::MARC::Utils::VERSION, 0.02, 'Version.');
