package Plack::App::NKC::MARC::Output;

use base qw(Plack::Component::Tags::HTML);
use strict;
use warnings;

use Data::HTML::Element::Option;
use Data::HTML::Element::Select;
use Data::NKC::MARC::Menu;
use English;
use Error::Pure qw(err);
use List::Util 1.33 qw(none);
use MARC::File::XML;
use MARC::Record;
use NKC::Transform::BIBFRAME2MARC;
use NKC::Transform::MARC2BIBFRAME;
use NKC::Transform::MARC2RDA;
use Plack::App::NKC::MARC::Utils qw(add_message detect_search select_data);
use Plack::Request;
use Plack::Session;
use Plack::Util::Accessor qw(footer lang version zoom);
use Readonly;
use Scalar::Util qw(blessed);
use Tags::HTML::Container;
use Tags::HTML::Element::Select;
use Tags::HTML::Footer 0.03;
use Tags::HTML::Messages;
use Tags::HTML::NKC::MARC::Menu;
use Tags::HTML::XML::Raw;
use Tags::HTML::XML::Raw::Color;
use Unicode::UTF8 qw(decode_utf8);
use ZOOM;

Readonly::Array our @OUTPUT_MODES => qw(xml_raw xml_raw_color);

our $VERSION = 0.10;

sub _cleanup {
	my ($self, $env) = @_;

	$self->{'_tags_container'}->cleanup;
	$self->{'_tags_footer'}->cleanup;
	$self->{'_tags_messages'}->cleanup;
	$self->{'_tags_menu'}->cleanup;
	$self->{'_tags_xml_raw'}->cleanup;
	$self->{'_tags_xml_raw_color'}->cleanup;
	$self->{'_tags_select_output'}->cleanup;

	return;
}

sub _css {
	my ($self, $env) = @_;

	$self->{'_tags_container'}->process_css;
	$self->{'_tags_footer'}->process_css;
	$self->{'_tags_messages'}->process_css({
		'error' => 'red',
		'info' => 'green',
	});
	$self->{'_tags_menu'}->process_css;
	$self->{'_tags_xml_raw'}->process_css;
	$self->{'_tags_xml_raw_color'}->process_css;

	$self->{'css'}->put(
		['s', '#input'],
		['d', 'margin-left', '1em'],
		['e'],

		['s', '#input select'],
		['d', 'margin-bottom', '1em'],
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
	$self->{'_zoom'} = eval {
		ZOOM::Connection->new(
			$self->{'_zoom_data'}->host,
			$self->{'_zoom_data'}->port,
			'databaseName' => $self->{'_zoom_data'}->db,
		);
	};
	if ($EVAL_ERROR) {
		add_message(
			$self,
			$env,
			'error',
			decode_utf8('Nemůžu se připojit na \''.$self->{'_zoom_data'}->host.'\'.'),
		);
		return;
	}
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

	$self->{'_transformation_bibframe2marc'} = NKC::Transform::BIBFRAME2MARC->new;
	$self->{'_transformation_marc2bibframe'} = NKC::Transform::MARC2BIBFRAME->new;
	$self->{'_transformation_marc2rda'} = NKC::Transform::MARC2RDA->new;

	my %p = (
		'css' => $self->css,
		'tags' => $self->tags,
	);
	$self->{'_tags_container'} = Tags::HTML::Container->new(%p,
		'height' => '1%',
		'padding' => '0.5em',
		'vert_align' => 'top',
	);
	$self->{'_tags_footer'} = Tags::HTML::Footer->new(%p);
	$self->{'_tags_messages'} = Tags::HTML::Messages->new(%p,
		'flag_no_messages' => 0,
	);
	$self->{'_tags_menu'} = Tags::HTML::NKC::MARC::Menu->new(%p,
		'mode_search' => 1,
	);
	$self->{'_tags_xml_raw'} = Tags::HTML::XML::Raw->new(%p);
	$self->{'_tags_xml_raw_color'} = Tags::HTML::XML::Raw::Color->new(%p);
	$self->{'_tags_select_output'} = Tags::HTML::Element::Select->new(%p);
	$self->{'_tags_select_trans'} = Tags::HTML::Element::Select->new(%p);

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
		my $input = $self->{'_marc'}->as_xml;

		# Transformation.
		my $output;
		if ($self->{'_transformation'} eq 'marc') {
			$output = $input;
			$self->{'_output'} = 'MARC';
		} elsif ($self->{'_transformation'} eq 'marc2bibframe') {
			$output = $self->{'_transformation_marc2bibframe'}->transform($input);
			$self->{'_output'} = 'BIBFRAME';
		} elsif ($self->{'_transformation'} eq 'marc2bibframe2marc') {
			$output = $self->{'_transformation_marc2bibframe'}->transform($input);
			$output = $self->{'_transformation_bibframe2marc'}->transform($output);
			$self->{'_output'} = 'MARC';
		} elsif ($self->{'_transformation'} eq 'marc2rda') {
			$output = $self->{'_transformation_marc2rda'}->transform($input);
			$self->{'_output'} = 'RDA';
		}

		# Output.
		if ($self->{'_output_mode'} eq 'xml_raw') {
			$self->{'_tags_xml_raw'}->init($output);
		} elsif ($self->{'_output_mode'} eq 'xml_raw_color') {
			$self->{'_tags_xml_raw_color'}->init($output);
			$self->css_src($self->{'_tags_xml_raw_color'}->css_src);
			$self->script_js($self->{'_tags_xml_raw_color'}->script_js);
			$self->script_js_src($self->{'_tags_xml_raw_color'}->script_js_src);
		}
	}

	my $select_trans = select_data($self, {
		'name' => 'transformation',
		'onchange' => 'this.form.submit();',
	}, [
		Data::HTML::Element::Option->new(
			'data' => [decode_utf8('—')],
			'value' => 'marc',
			$self->{'_transformation'} eq 'marc' ? ('selected' => 1) : (),
		),
		Data::HTML::Element::Option->new(
			'data' => ['MARC2BIBFRAME'],
			'value' => 'marc2bibframe',
			$self->{'_transformation'} eq 'marc2bibframe' ? ('selected' => 1) : (),
		),
		Data::HTML::Element::Option->new(
			'data' => ['MARC2BIBFRAME2MARC'],
			'value' => 'marc2bibframe2marc',
			$self->{'_transformation'} eq 'marc2bibframe2marc' ? ('selected' => 1) : (),
		),
		Data::HTML::Element::Option->new(
			'data' => ['MARC2RDA'],
			'value' => 'marc2rda',
			$self->{'_transformation'} eq 'marc2rda' ? ('selected' => 1) : (),
		),
	]);
	$self->{'_tags_select_trans'}->init($select_trans);

	my $select_output = select_data($self, {
		'name' => 'output_mode',
		'onchange' => 'this.form.submit();',
	}, [
		Data::HTML::Element::Option->new(
			'data' => ['XML'],
			'value' => 'xml_raw',
			$self->{'_output_mode'} eq 'xml_raw' ? ('selected' => 1) : (),
		),
		Data::HTML::Element::Option->new(
			'data' => ['XML color'],
			'value' => 'xml_raw_color',
			$self->{'_output_mode'} eq 'xml_raw_color' ? ('selected' => 1) : (),
		),
	]);
	$self->{'_tags_select_output'}->init($select_output);

	$self->{'_tags_footer'}->init($self->footer);

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

	# Transformation.
	$self->{'_transformation'} = $req->parameters->{'transformation'} || 'marc';

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
	my $error = 0;
	if (exists $env->{'psgix.session'}) {
		my $session = Plack::Session->new($env);
		$messages_ar = $session->get('messages');
		foreach my $message (@{$messages_ar}) {
			if ($message->type eq 'error') {
				$error = 1;
				last;
			}
		}
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

	if ($error) {
		return;
	}

	$self->{'tags'}->put(
		['b', 'form'],
		['a', 'method', 'get'],
		['a', 'action', '/output'],
		['a', 'id', 'input'],

		['b', 'input'],
		['a', 'type', 'hidden'],
		['a', 'value', $self->{'_search'}],
		['a', 'name', 'search'],
		['e', 'input'],

		['b', 'b'],
		['d', 'Vstup:'],
		['e', 'b'],
		['d', ' MARC z Z39.50 NKP'],
		['d', ', '],

		['b', 'b'],
		['d', 'Transformace:'],
		['e', 'b'],
		['d', ' '],
	);
	$self->{'_tags_select_trans'}->process;
	$self->{'tags'}->put(
		['d', ', '],

		['b', 'b'],
		['d', decode_utf8('Výstup:')],
		['e', 'b'],
		['d', ' '.$self->{'_output'}.' '],
	);
	$self->{'_tags_select_output'}->process;

	$self->{'tags'}->put(
		['e', 'form'],
	);

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
	$self->{'_tags_footer'}->process;

	return;
}

1;

__END__
