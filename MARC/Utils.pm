package Plack::App::NKC::MARC::Utils;

use base qw(Exporter);
use strict;
use warnings;

use Business::ISBN;
use Business::ISSN;
use Data::HTML::Element::Select;
use Data::Message::Simple;
use Plack::Session;
use Readonly;
use Tags::HTML::Element::Option;

Readonly::Array our @EXPORT_OK => qw(add_message detect_search select_data);

our $VERSION = 0.03;

sub add_message {
	my ($self, $env, $message_type, $message) = @_;

	my $session = Plack::Session->new($env);
	my $m = Data::Message::Simple->new(
		'text' => $message,
		'type' => $message_type,
	);
	my $messages_ar = $session->get('messages');
	if (defined $messages_ar) {
		push @{$messages_ar}, $m;
	} else {
		$session->set('messages', [$m]);
	}

	return;
}

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
		if (defined $issn) {
			if (! $issn->is_valid) {
				$issn->fix_checksum;
			}
			if ($issn->is_valid) {
				$search_issn = $issn->as_string;
			}
		}
	}

	return ($search_ccnb, $search_isbn, $search_issn);
}

sub select_data {
	my ($self, $params_hr, $options_ar) = @_;

	my $select_data = Data::HTML::Element::Select->new(
		'data' => [sub {
			my $self = shift;
			foreach my $option (@{$options_ar}) {
				my $tags_option = Tags::HTML::Element::Option->new(
					'css' => $self->{'css'},
					'tags' => $self->{'tags'},
				);
				$tags_option->init($option);
				$tags_option->process_css;
				$tags_option->process;
			}
		}],
		'data_type' => 'cb',
		%{$params_hr},
	);

	return $select_data;
}

1;
