use strict;
use warnings;

use Plack::App::NKC::MARC::List;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Plack::App::NKC::MARC::List::VERSION, 0.07, 'Version.');
