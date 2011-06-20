use strict;
use warnings;
package RDF::Light::Source;

use Plack::Request;
use RDF::Trine qw(iri statement);
use Scalar::Util qw(blessed);

use parent 'Exporter';
use Carp;
our @EXPORT = qw(dummy_source);
our @EXPORT_OK = qw(source is_source dummy_source);

our $rdf_type      = iri('http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
our $rdfs_Resource = iri('http://www.w3.org/2000/01/rdf-schema#Resource');

sub new {
    my $class = 'RDF::Light::Source';

	my $code = sub { };

	if ( @_ == 1 ) {
	    my $src = shift;
	    if (blessed $src and $src->isa('RDF::Light::Source')) {
	        return $src; # don't wrap
		} elsif ( blessed $src and $src->isa('RDF::Trine::Model') ) {
		    $code = sub {
                my $uri = RDF::Light::uri( shift );
	            $src->bounded_description( iri( $uri ) );
			};
		} elsif ( ref $src and ref $src eq 'CODE' ) {
		    $code = $src;
		} elsif (not defined $src) {
		    $code = sub { }; # TODO: warn?
		} else {
		    croak 'expected RDF::Light::Source, RDF::Trine::Model, or code reference';
		}
	} # TODO?
    #my $class = shift;
#    if ( grep { !is_source($_) } @_ ) {
#        croak 'Expected a RDF::Light::Source, RDF::Trine::Model, or CODE ref';
#	}
#
	bless { code => $code }, $class;
}

sub retrieve {
    my ($self, $env) = @_;
    $self->{code}->( $env );
}

sub source { new(@_) }

sub is_source {
    my $s = shift;
    (ref $s and ref $s eq 'CODE') or blessed($s) and 
	    ($s->isa('RDF::Light::Source') or $s->isa('RDF::Trine::Model'));
}

sub pipe {
    my ($self, $next) = @_;
	return source( sub {
	    my $res = $self->retrieve(shift);
		return unless defined $res;
		# TODO: if not empty: retrieve next and create union
	} );
}

sub dummy_source {
    my $env = shift;
    my $uri = RDF::Light::uri( $env );

    my $model = RDF::Trine::Model->temporary_model;
    $model->add_statement( statement( iri($uri), $rdf_type, $rdfs_Resource ) );

    return $model;
}

1;

__END__

=head1 DESCRIPTION

A source returns RDF data as instance of L<RDF::Trine::Model> or 
L<RDF::Trine::Iterator> when queried by a L<PSGI> requests. This is 
similar to PSGI applications, which return HTTP responses instead of 
RDF data. RDF::Light supports three types of sources: code references,
instances of RDF::Light::Source, and instances of RDF::Trine::Model.

=head1 SYNOPSIS

    # RDF::Light::Source as source
    $src = RDF::Light::Source->new( @other_sources );

    # retrieve RDF data
	$rdf = $src->retrieve( $env );
	$rdf = $src->( $env ); # use source as code reference

    # code reference as source
    $src = sub {
        my $env = shift;
        my $uri = RDF::Light::uri( $env );
        my $model = RDF::Trine::Model->temporary_model;
        add_some_statements( $uri, $model );
        return $model;
    };

	# RDF::Trine::Model as source returns same as the following sub:
    $src = $model; 
    $src = sub {
        my $uri = RDF::Light::uri( shift );
	    return $model->bounded_description( RDF::Trine::iri( $uri ) );
	}

    # Check whether $src is a valid source
    RDF::Light::Source::is_source( $src );

    # It is recommended to define your source as package
    package MySource;
    use parent 'RDF::Light::Source';

    sub retrieve {
	    my ($self, $env) = shift;
		# ..your logic here...
	}

=head1 METHODS

=head2 new ( [ @sources ] )
=head2 source ( [ @sources ] )

Returns a new source, possibly by wrapping a set of other sources. Croaks if
any if the passes sources is no RDF::Light::Source, RDF::Trine::Model, or 
CODE reference. This constructor can also be exported as function C<source>:

  use RDF::Light::Source qw(source);

  $src = source( @args );                      # short form
  $src = RDF::Light::Source->source( @args );  # equivalent
  $src = RDF:Light::Source->new( @args );      # explicit constructor

=head2 is_source

Checks whether the object is a valid source. C<< $source->is_source >> is 
always true, but you can also use and export this method as function:

  use RDF::Light::Source qw(is_source);
  is_source( $src );

=item dummy_source

This source returns a single triple such as the following, based on the
request URI. The request URI is either taken from the PSGI request variable
'rdflight.uri' or build from the request's base and path:

    <http://example.org/your/request> rdf:type rdfs:Resource .

=cut
