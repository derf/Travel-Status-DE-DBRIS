package Travel::Status::DE::DBRIS::Location;

use strict;
use warnings;
use 5.020;

use parent 'Class::Accessor';

our $VERSION = '0.01';

Travel::Status::DE::DBRIS::Location->mk_ro_accessors(
	qw(eva id lat lon name products type));

sub new {
	my ( $obj, %opt ) = @_;

	my $json = $opt{json};

	my $ref = {
		eva      => $json->{extId},
		id       => $json->{id},
		lat      => $json->{lat},
		lon      => $json->{lon},
		name     => $json->{name},
		products => $json->{products},
		type     => $json->{type},
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
