package Plack::App::NKC::MARC::List;

use base qw(Plack::Component::Tags::HTML);
use strict;
use warnings;

use Data::HTML::Element::A;
use File::Share ':all';
use IO::File;
use Plack::Request;
use Plack::Session;
use Plack::Util::Accessor qw(lang version);
use Readonly;
use Tags::HTML::Container;
use Tags::HTML::Messages;
use Tags::HTML::NKC::MARC::Menu;
use Tags::HTML::Table::View;
use Text::CSV_XS;
use Unicode::UTF8 qw(decode_utf8);

Readonly::Scalar our $FOOTER_HEIGHT => qw(40px);

our $VERSION = 0.07;

sub _cleanup {
	my ($self, $env) = @_;

	$self->{'_tags_container'}->cleanup;
	$self->{'_tags_menu'}->cleanup;
	$self->{'_tags_messages'}->cleanup;
	$self->{'_tags_table'}->cleanup;

	return;
}

sub _css {
	my ($self, $env) = @_;

	$self->{'_tags_container'}->process_css;
	$self->{'_tags_menu'}->process_css;
	$self->{'_tags_messages'}->process_css({
		'error' => 'red',
		'info' => 'green',
	});
	$self->{'_tags_table'}->process_css;

	$self->{'css'}->put(
		['s', '#main'],
		['d', 'padding-bottom', $FOOTER_HEIGHT],
		['e'],

		['s', 'footer'],
		['d', 'text-align', 'center'],
		['d', 'padding', '10px 0'],
		['d', 'background-color', '#f3f3f3'],
		['d', 'color', '#333'],
		['d', 'position', 'fixed'],
		['d', 'bottom', 0],
		['d', 'width', '100%'],
		['d', 'height', $FOOTER_HEIGHT],
		['e'],
	);

	return;
}

sub _lang {
	my ($self, $key) = @_;

	$self->{'_lang'} = {
		'ces' => {
			'page_title' => 'MARC demo',
		},
		'eng' => {
			'page_title' => 'MARC demo',
		},
	};

	return $self->{'_lang'}->{$self->lang}->{$key};
}

sub _prepare_app {
	my $self = shift;

	# Inherite defaults.
	$self->SUPER::_prepare_app;

	my %p = (
		'css' => $self->css,
		'tags' => $self->tags,
	);
	$self->{'_tags_container'} = Tags::HTML::Container->new(%p,
		'height' => '1%',
		'padding' => '0.5em',
		'vert_align' => 'top',
	);
	$self->{'_tags_messages'} = Tags::HTML::Messages->new(%p,
		'flag_no_messages' => 0,
	);
	$self->{'_tags_menu'} = Tags::HTML::NKC::MARC::Menu->new(%p);
	$self->{'_tags_table'} = Tags::HTML::Table::View->new(%p);

	$self->{'_menu_data'} = Data::NKC::MARC::Menu->new(
		'logo_image_location' => '/img/logo.png',
		'logo_location' => '/',
	);

	# Read CSV file and set to table.
	my $csv = Text::CSV_XS->new({
		'binary' => 1,
		'sep_char' => ',',
	});
	my $fh = IO::File->new;
	my $csv_file = dist_dir('Plack-App-NKC-MARC').'/data_cnb.csv';
	$fh->open($csv_file, 'r');
	$self->{'_table_data'} = [];
	my $num = 1;
	while (my $columns_ar = $csv->getline($fh)) {
		if (! @{$columns_ar}) {
			last;
		}
		if ($num > 1) {
			my $first;
			if ($columns_ar->[0] =~ m/^cnb\d+$/ms) {
				$first = Data::HTML::Element::A->new(
					'data' => [$columns_ar->[0]],
					'url' => '/output?search='.$columns_ar->[0],
				),
			} else {
				$first = $columns_ar->[0];
			}

			my $last;
			if ($columns_ar->[3] =~ m/^Q\d+$/ms) {
				$last = Data::HTML::Element::A->new(
					'data' => [$columns_ar->[3]],
					'url' => 'https://www.wikidata.org/wiki/'.$columns_ar->[3],
				);
			} else {
				$last = $columns_ar->[3];
			}
			push @{$self->{'_table_data'}}, [
				$first,
				$columns_ar->[1],
				$columns_ar->[2],
				$last,
			];
		} else {
			push @{$self->{'_table_data'}}, $columns_ar;
		}
		$num++;
	}

	return;
}

sub _process_actions {
	my ($self, $env) = @_;

	$self->{'_tags_menu'}->init($self->{'_menu_data'});
	$self->{'_tags_table'}->init($self->{'_table_data'});

	return;
}

sub _tags_middle {
	my ($self, $env) = @_;

	# Process messages.
	my $messages_ar = [];
	if (exists $env->{'psgix.session'}) {
		my $session = Plack::Session->new($env);
		$messages_ar = $session->get('messages');
		$session->set('messages', []);
	}
	$self->{'_tags_menu'}->process;
	$self->{'_tags_container'}->process(
		sub {
			$self->{'_tags_messages'}->process($messages_ar);
		},
	);

	# Main.
	$self->{'tags'}->put(
		['b', 'div'],
		['a', 'id', 'main'],
	);
	$self->{'_tags_table'}->process;
	$self->{'tags'}->put(
		['e', 'div'],
	);

	# Footer.
	$self->{'tags'}->put(
		['b', 'footer'],
		['b', 'a'],
		['a', 'href', '/changes'],
		['d', 'Verze: '.(defined $self->version ? $self->version : $VERSION)],
		['e', 'a'],
		['d', ',&nbsp;'],
		# XXX Automatic year.
		['d', decode_utf8('© 2024 ')],
		['b', 'a'],
		['a', 'href', 'https://skim.cz'],
		['d', decode_utf8('Michal Josef Špaček')],
		['e', 'a'],
		['e', 'footer'],
	);

	return;
}

1;

__END__
