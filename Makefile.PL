use lib '.';
use strict;
use warnings;

use inc::Module::Install;

# Definition.
abstract 'Plack application for NKC MARC.';
author 'Michal Josef Spacek <skim@cpan.org>';
author_requires 'English' => 0;
author_requires 'File::Object' => 0;
author_requires 'Test::More' => 0;
author_requires 'Test::NoWarnings' => 0;
author_requires 'Test::Pod' => 0;
author_requires 'Test::Pod::Coverage' => 0;
license 'bsd';
name 'Plack-App-NKC-MARC';
perl_version 5.008;
readme_from 'MARC.pm';
recursive_author_tests('xt');
requires 'Business::ISBN' => 0;
requires 'Business::ISSN' => 0;
requires 'Plack::App::CPAN::Changes' => 0;
requires 'Plack::App::Search' => 0.04;
requires 'Plack::App::URLMap' => 0;
requires 'Plack::Component' => 0;
requires 'Plack::Session' => 0;
requires 'Plack::Util::Accessor' => 0;
requires 'Tags::HTML::Container' => 0.07;
requires 'Unicode::UTF8' => 0;
resources 'bugtracker' => 'https://github.com/michal-josef-spacek/Plack-App-NKC-MARC/issues';
resources 'homepage' => 'https://github.com/michal-josef-spacek/Plack-App-NKC-MARC';
resources 'repository' => 'git://github.com/michal-josef-spacek/Plack-App-NKC-MARC';
test_requires 'Test::More' => 0;
test_requires 'Test::NoWarnings' => 0;
tests_recursive;
version '0.01';

# Run.
WriteAll();
