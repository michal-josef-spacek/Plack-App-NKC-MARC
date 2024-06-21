use strict;
use warnings;

use Plack::App::NKC::MARC::Output;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Plack::App::NKC::MARC::Output::VERSION, 0.1, 'Version.');
