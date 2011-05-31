use strict;
use warnings;
package RDF::Light;

=head1 NAME

RDF::Light - Simplified Linked Data handling

=head1 SYNOPSIS

    use Plack::Builder;
    use Plack::Request;
    use RDF::Light;

    my $model = RDF::Trine::Model->new( ... );

    my $app = sub {
        my $env = shift;
        my $req = Plack::Request->new($env);
        my $uri = $env->{'rdflight.uri'} || $req->base.$req->path;

        [ 404, ['Content-Type'=>'text/plain'], 
               ["URI $uri not found or not requested as RDF"] ];
    };

    builder {
        enable "+RDF::Light", source => $model;
        $app;
    }

=head1 INTRODUCTION

This package provides a PSGI application to serve RDF as Linked Data. This is
done by disallowing frament identifiers and query parts in URIs and by
disregarding the distinction between information-resources and non-information
resources. Some Semantic Web evangelists will be angry about this. By now this
package is experimental. For a more complete package see L<RDF::LinkedData>.

The package implements a PSGI application that can be used as
L<Plack::Middleware> to provide RDF data. The implementation is based on
L<RDF::Trine> which is a full implementation of RDF standards in Perl.

=cut

use Try::Tiny;
use Plack::Request;
use RDF::Trine qw(iri statement);
use RDF::Trine::Serializer;
use Carp;

use RDF::Light::Source;

use parent 'Plack::Middleware';
use Plack::Util::Accessor qw(source formats);

use parent 'Exporter';
our @EXPORT_OK = qw(guess_serialization);

our %rdf_formats = (
    nt     => 'ntriples',
    rdf    => 'rdfxml',
    xml    => 'rdfxml',
    rdfxml => 'rdfxml',
    json   => 'rdfjson',
    ttl    => 'turtle'
);

# TODO:
# * Show how to add custom serializers

sub prepare_app {
    my $self = shift;

    if ( UNIVERSAL::isa( $self->source, 'RDF::Trine::Model' ) ) {
        $self->source( model_source( $self->source ) ); # TODO: test this
    } elsif ( $self->source ) {
        ref $self->source eq 'CODE' or carp 'source must be a code reference';
    } else {
        $self->source( \&empty_source );
    }

    # TODO: support array ref and custom serialization formats
    if ( $self->formats ) {
        ref $self->formats eq 'HASH' or carp 'formats must be a hash reference';
    } else {
        $self->formats( \%rdf_formats );
    }

    # TODO: support file extensions and disabling formats
}

sub call {
    my $self = shift;
    my $env = shift;

    my $app = $self->app;
    my $req = Plack::Request->new( $env );

    my ($type, $serializer) = $self->guess_serialization( $env );

    if ($type) {
        # TODO: document this variables
        $env->{'rdflight.type'}       = $type;
        $env->{'rdflight.serializer'} = $serializer;

        my $rdf = $self->source->( $env );

        # TODO: support iterator and check whether iterator or model

        if ( $rdf->size > 0 ) {
            my $rdf_data  = $serializer->serialize_model_to_string( $rdf );
	    return [ 200, [ 'Content-Type' => $type ], [ $rdf_data ] ];
        }
    }
 
    # pass through if no/unknown serializer or empty source (URI not found)
    return $app->( $env );
}

sub guess_serialization {
    my $env = shift;
    my ($self, $possible_formats);

    if (UNIVERSAL::isa($env,'RDF::Light')) {
        ($self, $env) = ($env, shift);
        $possible_formats = $self->formats;
    } else {
        $possible_formats = \%rdf_formats; 
    }

    # TODO: check $env{rdflight.type} / $env{rdflight.serializer}

    my $accept = $env->{HTTP_ACCEPT} || '';
    my $req    = Plack::Request->new( $env );
    my $format = $req->param('format') || ''; # TODO: also support extensions

    my ($type, $serializer);

    if ($format ne '') {
        try {
            $serializer = RDF::Trine::Serializer->new( $possible_formats->{$format} );
            ($type) = $serializer->media_types;
        } # TODO: catch if unknown format or format not available
    } else {
        ($type, $serializer) = try { 
            RDF::Trine::Serializer->negotiate( request_headers => $req->headers );
            # TODO: maybe add extend => ...
        };
        if ($serializer) {
            ($type) = grep { index($accept,$_) >= 0 } $serializer->media_types;
            return unless $type; # the client must *explicitly* ask for this RDF serialization
        }
    }

    return ($type, $serializer);
}

=head1 METHODS

=head2 new ( [ %configuration ] )

Creates a new object.

=head2 CONFIGURATION

=over 4

=item source

Sets a code reference as RDF source (see L<RDF::Light::Source>) or a
L<RDF::Trine::Model> to query from.

=item formats

Defines supported serialization formats. You can either specify an array reference
with serializer names or a hash reference with mappings of format names to serializer 
names. Serializer names must exist in L<RDF::Trine::Serializer>::serializer_names.

  RDF::Light->new ( formats => [qw(ntriples rdfxml turtle)] )

  RDF::Light->new ( formats => {
      nt  => 'ntriples',
      rdf => 'rdfxml',
      xml => 'rdfxml',
      ttl => 'turtle'
  } );

=back

=head2 guess_serialization ( $env )

Given a PSGI request this function checks whether an RDF serialization format
has been B<explicitly> asked for, either by HTTP content negotiation or by
format query parameter or by file extension. You can call this as method or
as function and export it on request.

=cut

1;
