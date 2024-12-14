package Travel::Status::DE::DBRIS::Journey;

use strict;
use warnings;
use 5.020;

use parent 'Class::Accessor';

our $VERSION = '0.01';

Travel::Status::DE::DBRIS::Journey->mk_ro_accessors(
	qw(type dep sched_dep rt_dep delay is_cancelled line stop_name stop_eva id admin_id journey_id sched_platform platform dest_name dest_eva route)
);

sub new {
	my ( $obj, %opt ) = @_;

	my $json     = $opt{json}->[0];
	my $strptime = $opt{strptime_obj};

	my $ref = {
		type                => $json->{type},
		line                => $json->{lineName},
		is_cancelled        => $json->{canceled},
		dest_name           => $json->{destination}{name},
		platform            => $json->{platform},
		sched_platform      => $json->{platformSchedule},
		dest_eva            => $json->{destination}{evaNumber},
		raw_route           => $json->{viaStops},
		raw_cancelled_route => $json->{canceledStopsAfterActualDestination},
	};

	bless( $ref, $obj );

	if ( $json->{timeSchedule} ) {
		$ref->{sched_dep} = $strptime->parse_datetime( $json->{timeSchedule} );
	}
	if ( $json->{timeDelayed} ) {
		$ref->{rt_dep} = $strptime->parse_datetime( $json->{timeDelayed} );
	}
	$ref->{dep} = $ref->{rt_dep} // $ref->{schd_dep};

	if ( $ref->{sched_dep} and $ref->{rt_dep} ) {
		$ref->{delay} = $ref->{rt_dep}->subtract_datetime( $ref->{sched_dep} )
		  ->in_units('minutes');
	}

	return $ref;
}

sub route {
	my ($self) = @_;

	if ( $self->{route} ) {
		return @{ $self->{route} };
	}

	@{ $self->{route} }
	  = map { Travel::Status::DE::DBRIS::Location->new( json => $_ ) }
	  ( @{ $self->{raw_route} // [] },
		@{ $self->{raw_cancelled_route} // [] } );

	return @{ $self->{route} };
}

sub TO_JSON {
	my ($self) = @_;

	my $ret = { %{$self} };

	return $ret;
}

1;
