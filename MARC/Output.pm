package Plack::App::NKC::MARC::Output;

use base qw(Plack::Component::Tags::HTML);
use strict;
use warnings;

use Error::Pure qw(err);
use Plack::Request;
use Plack::Session;
use Plack::Util::Accessor qw(lang);
use Tags::HTML::Container;
use Tags::HTML::Messages;
use Unicode::UTF8 qw(decode_utf8);

our $VERSION = 0.01;

sub _cleanup {
	my ($self, $env) = @_;

	$self->{'_data_tags_after_title'} = [];
	$self->{'_tags_container'}->cleanup;
	$self->{'_tags_messages'}->cleanup;

	return;
}

sub _css {
	my ($self, $env) = @_;

	$self->{'_tags_container'}->process_css;
	$self->{'_tags_messages'}->process_css({
		'error' => 'red',
		'info' => 'green',
	});

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

	return;
}

sub _process_actions {
	my ($self, $env) = @_;

	my $session = Plack::Session->new($env);

	$self->_check_required_middleware($env);

	$self->{'_title'} = $self->_lang('page_title');

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
		},
	);

	return;
}


1;

__END__
