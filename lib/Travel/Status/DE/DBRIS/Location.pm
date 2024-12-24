package Travel::Status::DE::DBRIS::Location;

use strict;
use warnings;
use 5.020;

use parent 'Class::Accessor';

our $VERSION = '0.01';

Travel::Status::DE::DBRIS::Location->mk_ro_accessors(
	qw(eva id lat lon name products type is_cancelled is_additional is_separation display_priority
	  dep arr platform
	)
);

sub new {
	my ( $obj, %opt ) = @_;

	my $json = $opt{json};

	my $ref = {
		eva           => $json->{extId} // $json->{evaNumber},
		id            => $json->{id},
		lat           => $json->{lat},
		lon           => $json->{lon},
		name          => $json->{name},
		products      => $json->{products},
		type          => $json->{type},
		is_cancelled  => $json->{canceled},
		is_additional => $json->{additional},
		platform      => $json->{gleis},
		rt_platform   => $json->{ezGleis},
	};

	if ( $json->{abfahrtsZeitpunkt} ) {
		$ref->{sched_dep}
		  = $opt{strptime_obj}->parse_datetime( $json->{abfahrtsZeitpunkt} );
	}
	if ( $json->{ezAbfahrtsZeitpunkt} ) {
		$ref->{rt_dep}
		  = $opt{strptime_obj}->parse_datetime( $json->{ezAbfahrtsZeitpunkt} );
	}
	if ( $json->{ankunftsZeitpunkt} ) {
		$ref->{sched_arr}
		  = $opt{strptime_obj}->parse_datetime( $json->{ankunftsZeitpunkt} );
	}
	if ( $json->{ezAnkunftsZeitpunkt} ) {
		$ref->{rt_arr}
		  = $opt{strptime_obj}->parse_datetime( $json->{ezAnkunftsZeitpunkt} );
	}

	$ref->{arr} = $ref->{rt_arr} // $ref->{sched_arr};
	$ref->{dep} = $ref->{rt_dep} // $ref->{sched_dep};

	bless( $ref, $obj );

	return $ref;
}

sub TO_JSON {
	my ($self) = @_;

	my $ret = { %{$self} };

	return $ret;
}

1;
