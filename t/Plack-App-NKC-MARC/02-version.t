use strict;
use warnings;

use Plack::App::NKC::MARC;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Plack::App::NKC::MARC::VERSION, 0.06, 'Version.');
