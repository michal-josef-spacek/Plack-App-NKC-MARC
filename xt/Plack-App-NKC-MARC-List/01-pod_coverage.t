use strict;
use warnings;

use Test::NoWarnings;
use Test::Pod::Coverage 'tests' => 2;

# Test.
pod_coverage_ok('Plack::App::NKC::MARC::List', 'Plack::App::NKC::MARC::List is covered.');
