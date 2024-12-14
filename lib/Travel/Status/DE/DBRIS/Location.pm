package Travel::Status::DE::DBRIS::Location;

use strict;
use warnings;
use 5.020;

use parent 'Class::Accessor';

our $VERSION = '0.01';

Travel::Status::DE::DBRIS::Location->mk_ro_accessors(
	qw(eva id lat lon name products type is_cancelled is_additional is_separation display_priority)
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

	};

	bless( $ref, $obj );

	return $ref;
}

sub TO_JSON {
	my ($self) = @_;

	my $ret = { %{$self} };

	return $ret;
}

1;
