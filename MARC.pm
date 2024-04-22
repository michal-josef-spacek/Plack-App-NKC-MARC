package Plack::App::NKC::MARC;

use base qw(Plack::Component);
use strict;
use warnings;

use Plack::App::CPAN::Changes;
use Plack::App::NKC::MARC::List;
use Plack::App::NKC::MARC::Output;
use Plack::App::Search 0.04;
use Plack::App::URLMap;
use Plack::Session;
use Plack::Util::Accessor qw(changes css images lang tags zoom);
use Unicode::UTF8 qw(decode_utf8);

our $VERSION = 0.02;

sub call {
	my ($self, $env) = @_;

	my $session = Plack::Session->new($env);

	# Main application.
	return $self->{'_urlmap'}->to_app->($env);
}

sub prepare_app {
	my $self = shift;

	my %p = (
		'css' => $self->css,
		'lang' => 'ces',
		'tags' => $self->tags,
	);

	my $version;
	if (defined $self->changes) {
		$version = ($self->changes->releases)[-1]->version;
	}

	my %common_params = (
		%p,
		defined $version ? (
			'version' => $version,
		) : (),
	);

	my $app_list = Plack::App::NKC::MARC::List->new(
		%common_params,
	)->to_app;
	my $app_search = Plack::App::Search->new(
		%p,
		'image_height' => '10em',
		'image_link' => $self->images->{'logo'},
		'image_radius' => '15px',
		'search_placeholder' => decode_utf8('ČČNB, ISBN, ISSN'),
		'search_url' => '/marc',
		'tags_after' => [
			['b', 'a'],
			['a', 'href', '/list'],
			['a', 'style', 'font-size:1em;text-decoration:none;'],
			['d', decode_utf8('Seznam zajímavých položek')],
			['e', 'a'],
		],
	)->to_app;
	my $app_output = Plack::App::NKC::MARC::Output->new(
		%common_params,
		'zoom' => $self->zoom,
	)->to_app;
	my $app_changes;
	if (defined $self->changes) {
		$app_changes = Plack::App::CPAN::Changes->new(
			%p,
			'changes' => $self->changes,
		)->to_app;
	}

	$self->{'_urlmap'} = Plack::App::URLMap->new;
	$self->{'_urlmap'}->map('/' => $app_search);
	$self->{'_urlmap'}->map('/list' => $app_list);
	$self->{'_urlmap'}->map('/marc' => $app_output);
	if (defined $self->changes) {
		$self->{'_urlmap'}->map('/changes' => $app_changes);
	}

	return;
}

1;

__END__
