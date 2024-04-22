package Plack::App::NKC::MARC::Output;

use base qw(Plack::Component::Tags::HTML);
use strict;
use warnings;

use Data::NKC::MARC::Menu;
use Error::Pure qw(err);
use List::Util 1.33 qw(none);
use MARC::File::XML;
use MARC::Record;
use Plack::App::NKC::MARC::Utils qw(add_message detect_search);
use Plack::Request;
use Plack::Session;
use Plack::Util::Accessor qw(lang version zoom);
use Readonly;
use Scalar::Util qw(blessed);
use Tags::HTML::Container;
use Tags::HTML::Messages;
use Tags::HTML::NKC::MARC::Menu;
use Tags::HTML::XML::Raw;
use Tags::HTML::XML::Raw::Color;
use Unicode::UTF8 qw(decode_utf8);
use ZOOM;

Readonly::Array our @OUTPUT_MODES => qw(xml_raw xml_raw_color);
Readonly::Scalar our $FOOTER_HEIGHT => qw(40px);

our $VERSION = 0.01;

sub _cleanup {
	my ($self, $env) = @_;

	$self->{'_tags_container'}->cleanup;
	$self->{'_tags_messages'}->cleanup;
	$self->{'_tags_menu'}->cleanup;
	$self->{'_tags_xml_raw'}->cleanup;
	$self->{'_tags_xml_raw_color'}->cleanup;

	return;
}

sub _css {
	my ($self, $env) = @_;

	$self->{'_tags_container'}->process_css;
	$self->{'_tags_messages'}->process_css({
		'error' => 'red',
		'info' => 'green',
	});
	$self->{'_tags_menu'}->process_css;
	$self->{'_tags_xml_raw'}->process_css;
	$self->{'_tags_xml_raw_color'}->process_css;

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

sub _check_required_middleware {
	my ($self, $env) = @_;

	# Check use of Session before this app.
	if (! defined $env->{'psgix.session'}) {
		err 'No Plack::Middleware::Session present.';
	}

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

sub _load_data {
	my ($self, $env) = @_;

	# Zoom connections.
	$self->{'_zoom'} = ZOOM::Connection->new(
		$self->{'_zoom_data'}->host,
		$self->{'_zoom_data'}->port,
		'databaseName' => $self->{'_zoom_data'}->db,
	);
	$self->{'_zoom'}->option('preferredRecordSyntax' => 'usmarc');

	my $rs;
	if (defined $self->{'_search_ccnb'}) {
		$rs = $self->{'_zoom'}->search_pqf('@attr 1=48 '.$self->{'_search_ccnb'});
		$self->{'_searching'} = decode_utf8('ČČNB: '.$self->{'_search_ccnb'});
	} elsif (defined $self->{'_search_isbn'}) {
		$rs = $self->{'_zoom'}->search_pqf('@attr 1=7 '.$self->{'_search_isbn'});
		$self->{'_searching'} = decode_utf8('ISBN '.$self->{'_search_isbn'});
	} elsif (defined $self->{'_search_issn'}) {
		$rs = $self->{'_zoom'}->search_pqf('@attr 1=8 '.$self->{'_search_issn'});
		$self->{'_searching'} = decode_utf8('ISSN '.$self->{'_search_issn'});
	} else {
		add_message(
			$self,
			$env,
			'error',
			decode_utf8('Nemůžu najít požadováné dílo.'),
		);
		return;
	}

	# Cache.
	# TODO

	# Load data.
	if (defined $rs && $rs->size > 0) {
		my $raw_record = $rs->record(0)->raw;
		$self->{'_marc'} = MARC::Record->new_from_usmarc($raw_record);

		# Update ccnb id if doesn't defined in search.
		if (! defined $self->{'_search_ccnb'}) {
			my $ccnb = $self->_subfield('015', 'a');
			if (! $ccnb) {
				$ccnb = $self->_subfield('015', 'z');
			}
			$self->{'_search_ccnb'} = $ccnb;
		}
	} else {
		add_message(
			$self,
			$env,
			'error',
			decode_utf8('Nemůžu najít požadováné dílo.'),
		);
		return;
	}

	return;
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
	$self->{'_tags_menu'} = Tags::HTML::NKC::MARC::Menu->new(%p,
		'mode_search' => 1,
	);
	$self->{'_tags_xml_raw'} = Tags::HTML::XML::Raw->new(%p);
	$self->{'_tags_xml_raw_color'} = Tags::HTML::XML::Raw::Color->new(%p);

	$self->{'_zoom_data'} = $self->zoom;
	if (! defined $self->{'_zoom_data'}
		|| ! blessed($self->{'_zoom_data'})
		|| ! $self->{'_zoom_data'}->isa('Data::NKC::MARC::Zoom')) {

		err "ZOOM data object must be a 'Data::NKC::MARC::Zoom' instance.";
	}

	return;
}

sub _process_actions {
	my ($self, $env) = @_;

	my $session = Plack::Session->new($env);

	$self->_check_required_middleware($env);

	$self->{'_title'} = $self->_lang('page_title');

	$self->_process_form($env);
	$self->_load_data($env);

	my $menu = Data::NKC::MARC::Menu->new(
		'cnb_id' => $self->{'_search_ccnb'},
		'logo_image_location' => '/img/logo.png',
		'logo_location' => '/',
		'search' => $self->{'_search'},
		'searching' => $self->{'_searching'},
	);
	$self->{'_tags_menu'}->init($menu);

	# Clean CSS and Javascript in header. Because switching of systems.
	$self->css_src([]);
	$self->script_js([]);
	$self->script_js_src([]);

	if (defined $self->{'_marc'}) {
		if ($self->{'_output_mode'} eq 'xml_raw') {
			$self->{'_tags_xml_raw'}->init($self->{'_marc'}->as_xml);
		} elsif ($self->{'_output_mode'} eq 'xml_raw_color') {
			$self->{'_tags_xml_raw_color'}->init($self->{'_marc'}->as_xml);
			$self->css_src($self->{'_tags_xml_raw_color'}->css_src);
			$self->script_js($self->{'_tags_xml_raw_color'}->script_js);
			$self->script_js_src($self->{'_tags_xml_raw_color'}->script_js_src);
		}
	}

	return;
}

sub _process_form {
	my ($self, $env) = @_;

	my $req = Plack::Request->new($env);

	($self->{'_search_ccnb'}, $self->{'_search_issn'}, $self->{'_search_issn'})
		= (undef, undef, undef);
	$self->{'_marc'} = undef;
	$self->{'_searching'} = undef;

	# Check form processing.
	if (! $req->parameters->{'search'}) {
		return;
	}

	$self->{'_search'} = $req->parameters->{'search'};
	($self->{'_search_ccnb'}, $self->{'_search_isbn'}, $self->{'_search_issn'})
		= detect_search($self->{'_search'});

	# View mode.
	$self->{'_output_mode'} = $req->parameters->{'output_mode'};
	if (! defined $self->{'_output_mode'}) {
		$self->{'_output_mode'} = 'xml_raw_color';
	}
	if (none { $self->{'_output_mode'} eq $_ } @OUTPUT_MODES) {
		add_message(
			$self,
			$env,
			'error',
			decode_utf8('Špatný vykreslovací mód.'),
		);
	}

	return;
}

sub _subfield {
	my ($self, $field, $subfield) = @_;

	my $field_value = $self->{'_marc'}->field($field);
	if (! defined $field_value) {
		return;
	}

	return $field_value->subfield($subfield);
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

	# Input: __ID__ (ČČNB) Transformation: __Transformation__ (link) Output: __Output__
	# TODO

	# Main.
	$self->{'tags'}->put(
		['b', 'div'],
		['a', 'id', 'main'],
	);
	if ($self->{'_output_mode'} eq 'xml_raw') {
		$self->{'_tags_xml_raw'}->process;
	} elsif ($self->{'_output_mode'} eq 'xml_raw_color') {
		$self->{'_tags_xml_raw_color'}->process;
	}
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
