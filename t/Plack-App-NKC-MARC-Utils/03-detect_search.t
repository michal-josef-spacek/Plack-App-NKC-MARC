use strict;
use warnings;

use Plack::App::NKC::MARC::Utils qw(detect_search);
use Test::More 'tests' => 19;
use Test::NoWarnings;

# Test.
my ($ret_ccnb, $ret_isbn, $ret_issn) = detect_search('cnb001276596');
is($ret_ccnb, 'cnb001276596', 'Get CCNB search string (cnb001276596).');
is($ret_isbn, undef, 'Get ISBN search string (cnb001276596).');
is($ret_issn, undef, 'Get ISSN search string (cnb001276596).');

# Test.
($ret_ccnb, $ret_isbn, $ret_issn) = detect_search('80-86347-25-7');
is($ret_ccnb, undef, 'Get CCNB search string (80-86347-25-7).');
is($ret_isbn, '80-86347-25-7', 'Get ISBN search string (80-86347-25-7).');
is($ret_issn, undef, 'Get ISSN search string (80-86347-25-7).');

# Test.
($ret_ccnb, $ret_isbn, $ret_issn) = detect_search('8086347257');
is($ret_ccnb, undef, 'Get CCNB search string (8086347257, not formatted).');
is($ret_isbn, '80-86347-25-7', 'Get ISBN search string (8086347257, not formatted).');
is($ret_issn, undef, 'Get ISSN search string (8086347257, not formatted).');

# Test.
($ret_ccnb, $ret_isbn, $ret_issn) = detect_search('8086347256');
is($ret_ccnb, undef, 'Get CCNB search string (8086347256, bad checksum).');
is($ret_isbn, '80-86347-25-7', 'Get ISBN search string (8086347256, bad checksum).');
is($ret_issn, undef, 'Get ISSN search string (8086347256, bad checksum).');

# Test.
($ret_ccnb, $ret_isbn, $ret_issn) = detect_search('0374-6852');
is($ret_ccnb, undef, 'Get CCNB search string (0374-6852).');
is($ret_isbn, undef, 'Get ISBN search string (0374-6852).');
is($ret_issn, '0374-6852', 'Get ISSN search string (0374-6852).');

# Test.
($ret_ccnb, $ret_isbn, $ret_issn) = detect_search('foo');
is($ret_ccnb, undef, 'Get CCNB search string (foo).');
is($ret_isbn, undef, 'Get ISBN search string (foo).');
is($ret_issn, undef, 'Get ISSN search string (foo).');
