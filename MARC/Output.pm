package Plack::App::NKC::MARC::Output;

use base qw(Plack::Component::Tags::HTML);
use strict;
use warnings;

use Error::Pure qw(err);
use List::Util qw(none);
use MARC::File::XML;
use MARC::Record;
use Plack::App::NKC::MARC::Utils qw(detect_search);
use Plack::Request;
use Plack::Session;
use Plack::Util::Accessor qw(lang);
use Plack::Util::Accessor qw(zoom);
use Readonly;
use Scalar::Util qw(blessed);
use Tags::HTML::Container;
use Tags::HTML::Messages;
use Tags::HTML::XML::Raw;
use Tags::HTML::XML::Raw::Color;
use Unicode::UTF8 qw(decode_utf8);
use ZOOM;

Readonly::Array our @OUTPUT_MODES => qw(xml_raw xml_raw_color);

our $VERSION = 0.01;

sub _cleanup {
	my ($self, $env) = @_;

	$self->{'_data_tags_after_title'} = [];
	$self->{'_tags_container'}->cleanup;
	$self->{'_tags_messages'}->cleanup;
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
	$self->{'_tags_xml_raw'}->process_css;
	$self->{'_tags_xml_raw_color'}->process_css;

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
	my $self = shift;

	my $rs;
	if (defined $self->{'_search_ccnb'}) {
		$rs = $self->{'_zoom'}->search_pqf('@attr 1=48 '.$self->{'_search_ccnb'});
	} elsif (defined $self->{'_search_isbn'}) {
		$rs = $self->{'_zoom'}->search_pqf('@attr 1=7 '.$self->{'_search_isbn'});
	} elsif (defined $self->{'_search_issn'}) {
		$rs = $self->{'_zoom'}->search_pqf('@attr 1=8 '.$self->{'_search_issn'});
	} else {
		# TODO error.
	}

	# Cache.
	# TODO

	# Load data.
	if (defined $rs) {
		my $raw_record = $rs->record(0)->raw;
		$self->{'_marc'} = MARC::Record->new_from_usmarc($raw_record);
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
		'vert_align' => 'top',
	);
	$self->{'_tags_messages'} = Tags::HTML::Messages->new(%p,
		'flag_no_messages' => 0,
	);
	$self->{'_tags_xml_raw'} = Tags::HTML::XML::Raw->new(%p);
	$self->{'_tags_xml_raw_color'} = Tags::HTML::XML::Raw::Color->new(%p);

	my $zoom = $self->zoom;
	if (! defined $zoom
		|| ! blessed($zoom)
		|| ! $zoom->isa('Data::NKC::Zoom')) {

		err "ZOOM data object must be a 'Data::NKC::Zoom' instance.";
	}
	# Zoom connections.
	$self->{'_zoom'} = ZOOM::Connection->new(
		$zoom->host,
		$zoom->port,
		'databaseName' => $zoom->db,
	);
	$self->{'_zoom'}->option('preferredRecordSyntax' => 'usmarc');

	return;
}

sub _process_actions {
	my ($self, $env) = @_;

	my $session = Plack::Session->new($env);

	$self->_check_required_middleware($env);

	$self->{'_title'} = $self->_lang('page_title');

	$self->_process_form($env);
	$self->_load_data;

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
		$self->{'_output_mode'} = 'xml_raw';
	}
	# TODO Check modes.

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
	$self->{'_tags_container'}->process(
		sub {
			$self->{'_tags_messages'}->process($messages_ar);

			# Input: __ID__ (ČČNB) Transformation: __Transformation__ (link) Output: __Output__

			$self->{'tags'}->put(
				defined $self->{'_search_ccnb'} ? (
					['d', decode_utf8('ČČNB:').$self->{'_search_ccnb'}],
				) : (),
			);
			$self->_view_data;
		},
	);

	return;
}

sub _view_data {
	my $self = shift;

	if ($self->{'_output_mode'} eq 'xml_raw') {
		$self->{'_tags_xml_raw'}->process;
	} elsif ($self->{'_output_mode'} eq 'xml_raw_color') {
		$self->{'_tags_xml_raw_color'}->process;
	}
	# TODO

	return;
}

1;

__END__
