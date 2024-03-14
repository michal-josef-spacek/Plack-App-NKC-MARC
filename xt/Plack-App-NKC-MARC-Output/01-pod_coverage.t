use strict;
use warnings;

use Test::NoWarnings;
use Test::Pod::Coverage 'tests' => 2;

# Test.
pod_coverage_ok('Plack::App::NKC::MARC::Output', 'Plack::App::NKC::MARC::Output is covered.');
