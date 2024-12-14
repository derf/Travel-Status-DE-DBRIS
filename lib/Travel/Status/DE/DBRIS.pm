package Travel::Status::DE::DBRIS;

# vim:foldmethod=marker

use strict;
use warnings;
use 5.020;
use utf8;

use Carp qw(confess);
use DateTime;
use DateTime::Format::Strptime;
use Encode qw(decode encode);
use JSON;
use LWP::UserAgent;
use Travel::Status::DE::DBRIS::Journey;
use Travel::Status::DE::DBRIS::Location;

our $VERSION = '0.01';

# {{{ Constructors

sub new {
	my ( $obj, %conf ) = @_;
	my $service = $conf{service};

	my $ua = $conf{user_agent};

	if ( not $ua ) {
		my %lwp_options = %{ $conf{lwp_options} // { timeout => 10 } };
		$ua = LWP::UserAgent->new(%lwp_options);
		$ua->env_proxy;
	}

	my $now  = DateTime->now( time_zone => 'Europe/Berlin' );
	my $self = {
		cache          => $conf{cache},
		developer_mode => $conf{developer_mode},
		messages       => [],
		results        => [],
		station        => $conf{station},
		ua             => $ua,
		now            => $now,
		tz_offset      => $now->offset / 60,
	};

	bless( $self, $obj );

	my $req;

	if ( my $eva = $conf{station} ) {
		$req
		  = "https://www.bahnhof.de/api/boards/departures?evaNumbers=${eva}&duration=60&stationCategory=1&locale=de&sortBy=TIME";
	}
	elsif ( my $gs = $conf{geoSearch} ) {
		my $lat = $gs->{latitude};
		my $lon = $gs->{longitude};
		$req
		  = "https://www.bahn.de/web/api/reiseloesung/orte/nearby?lat=${lat}&long=${lon}&radius=9999&maxNo=100";
	}
	elsif ( my $query = $conf{locationSearch} ) {
		$req
		  = "https://www.bahn.de/web/api/reiseloesung/orte?suchbegriff=${query}&typ=ALL&limit=10";
	}

	# journey : https://www.bahn.de/web/api/reiseloesung/fahrt?journeyId=2%7C%23VN%231%23ST%231733779122%23PI%230%23ZI%23324190%23TA%230%23DA%23141224%231S%238000001%231T%231822%23LS%238000080%23LT%232050%23PU%2380%23RT%231%23CA%23DPN%23ZE%2326431%23ZB%23RE+26431%23PC%233%23FR%238000001%23FT%231822%23TO%238000080%23TT%232050%23&poly=true
	else {
		confess('station or geoSearch must be specified');
	}

	$self->{strptime_obj} //= DateTime::Format::Strptime->new(
		pattern   => '%Y-%m-%dT%H:%M:%S%Z',
		time_zone => 'Europe/Berlin',
	);

	my $json = $self->{json} = JSON->new->utf8;

	if ( $conf{async} ) {
		$self->{req} = $req;
		return $self;
	}

	if ( $conf{json} ) {
		$self->{raw_json} = $conf{json};
	}
	else {
		if ( $self->{developer_mode} ) {
			say "requesting $req";
		}

		my ( $content, $error ) = $self->get_with_cache($req);

		if ($error) {
			$self->{errstr} = $error;
			return $self;
		}

		if ( $self->{developer_mode} ) {
			say decode( 'utf-8', $content );
		}

		$self->{raw_json} = $json->decode($content);
	}

	if ( $conf{station} ) {
		$self->parse_stationboard;
	}
	elsif ( $conf{geoSearch} or $conf{locationSearch} ) {
		$self->parse_search;
	}

	return $self;
}

sub new_p {
	my ( $obj, %conf ) = @_;
	my $promise = $conf{promise}->new;

	if (
		not(   $conf{station}
			or $conf{geoSearch} )
	  )
	{
		return $promise->reject('station / geoSearch flag must be passed');
	}

	my $self = $obj->new( %conf, async => 1 );
	$self->{promise} = $conf{promise};

	$self->get_with_cache_p( $self->{url} )->then(
		sub {
			my ($content) = @_;
			$self->{raw_json} = $self->{json}->decode($content);
			if ( $conf{station} ) {
				$self->parse_stationboard;
			}
			elsif ( $conf{geoSearch} or $conf{locationSearch} ) {
				$self->parse_search;
			}
			else {
				$promise->resolve($self);
			}
			return;
		}
	)->catch(
		sub {
			my ($err) = @_;
			$promise->reject($err);
			return;
		}
	)->wait;

	return $promise;
}

# }}}
# {{{ Internal Helpers

sub get_with_cache {
	my ( $self, $url ) = @_;
	my $cache = $self->{cache};

	if ( $self->{developer_mode} ) {
		say "GET $url";
	}

	if ($cache) {
		my $content = $cache->thaw($url);
		if ($content) {
			if ( $self->{developer_mode} ) {
				say '  cache hit';
			}
			return ( ${$content}, undef );
		}
	}

	if ( $self->{developer_mode} ) {
		say '  cache miss';
	}

	my $reply = $self->{ua}->get($url);

	if ( $reply->is_error ) {
		return ( undef, $reply->status_line );
	}
	my $content = $reply->content;

	if ($cache) {
		$cache->freeze( $url, \$content );
	}

	return ( $content, undef );
}

sub get_with_cache_p {
	my ( $self, $url ) = @_;
	my $cache = $self->{cache};

	if ( $self->{developer_mode} ) {
		say "GET $url";
	}

	my $promise = $self->{promise}->new;

	if ($cache) {
		my $content = $cache->thaw($url);
		if ($content) {
			if ( $self->{developer_mode} ) {
				say '  cache hit';
			}
			return $promise->resolve( ${$content} );
		}
	}

	if ( $self->{developer_mode} ) {
		say '  cache miss';
	}

	$self->{ua}->get_p($url)->then(
		sub {
			my ($tx) = @_;
			if ( my $err = $tx->error ) {
				$promise->reject(
					"GET $url returned HTTP $err->{code} $err->{message}");
				return;
			}
			my $content = $tx->res->body;
			if ($cache) {
				$cache->freeze( $url, \$content );
			}
			$promise->resolve($content);
			return;
		}
	)->catch(
		sub {
			my ($err) = @_;
			$promise->reject($err);
			return;
		}
	)->wait;

	return $promise;
}

sub parse_search {
	my ($self) = @_;

	@{ $self->{results} }
	  = map { Travel::Status::DE::DBRIS::Location->new( json => $_ ) }
	  @{ $self->{raw_json} // [] };

	return $self;
}

sub parse_stationboard {
	my ($self) = @_;

	# @{$self->{messages}} = map { Travel::Status::DE::DBRIS::Message->new(...) } @{$self->{raw_json}{globalMessages}/[]};

	@{ $self->{results} } = map {
		Travel::Status::DE::DBRIS::Journey->new(
			json         => $_,
			strptime_obj => $self->{strptime_obj}
		)
	} @{ $self->{raw_json}{entries} // [] };

	return $self;
}

# }}}
# {{{ Public Functions

sub errstr {
	my ($self) = @_;

	return $self->{errstr};
}

sub results {
	my ($self) = @_;
	return @{ $self->{results} };
}

sub result {
	my ($self) = @_;
	return $self->{result};
}

# }}}

1;
