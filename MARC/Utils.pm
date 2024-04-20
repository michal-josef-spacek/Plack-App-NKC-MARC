package Plack::App::NKC::MARC::Utils;

use base qw(Exporter);
use strict;
use warnings;

use Business::ISBN;
use Business::ISSN;
use Readonly;

Readonly::Array our @EXPORT_OK => qw(detect_search);

our $VERSION = 0.01;

sub detect_search {
	my $search_string = shift;

	my ($search_ccnb, $search_isbn, $search_issn);

	# Detect CCNB.
	if ($search_string =~ m/^cnb\d+$/ms) {
		$search_ccnb = $search_string;
	}

	# Detect ISBN.
	if (! defined $search_ccnb) {
		my $isbn = Business::ISBN->new($search_string);
		if (defined $isbn) {
			if (! $isbn->is_valid) {
				$isbn->fix_checksum;
			}
			if ($isbn->is_valid) {
				my $isbn_without_dash = $search_string;
				$isbn_without_dash =~ s/-//msg;
				if (length $isbn_without_dash > 10) {
					$search_isbn = $isbn->as_isbn13->as_string;
				} else {
					$search_isbn = $isbn->as_isbn10->as_string;
				}
			}
		}
	}

	# Detect ISSN.
	if (! defined $search_ccnb && ! defined $search_isbn) {
		my $issn = Business::ISSN->new($search_string);
		if (defined $issn && $issn->is_valid) {
			$search_issn = $search_string;
		}
		# TODO Fix checksum.
	}

	# Detect CNB.
	# TODO

	return ($search_ccnb, $search_isbn, $search_issn);
}

1;
