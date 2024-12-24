package Travel::Status::DE::DBRIS::Journey;

use strict;
use warnings;
use 5.020;

use parent 'Class::Accessor';

use Travel::Status::DE::DBRIS::Location;

our $VERSION = '0.01';

Travel::Status::DE::DBRIS::Journey->mk_ro_accessors(qw(train is_cancelled));

sub new {
	my ( $obj, %opt ) = @_;

	my $json     = $opt{json};
	my $strptime = $opt{strptime_obj};

	my $ref = {
		train        => $json->{zugName},
		is_cancelled => $json->{cancelled},
		raw_route    => $json->{halte},
		strptime_obj => $strptime,
	};

	bless( $ref, $obj );

	for my $message ( @{ $json->{himMeldungen} // [] } ) {
		push( @{ $ref->{messages} }, $message );
	}

	return $ref;
}

sub route {
	my ($self) = @_;

	if ( $self->{route} ) {
		return @{ $self->{route} };
	}

	@{ $self->{route} }
	  = map {
		Travel::Status::DE::DBRIS::Location->new(
			json         => $_,
			strptime_obj => $self->{strptime_obj}
		)
	  } ( @{ $self->{raw_route} // [] },
		@{ $self->{raw_cancelled_route} // [] } );

	return @{ $self->{route} };
}

sub messages {
	my ($self) = @_;

	return @{ $self->{messages} // [] };
}

sub TO_JSON {
	my ($self) = @_;

	my $ret = { %{$self} };

	return $ret;
}

1;
