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
        my $uri = RDF::Light::uri( $env );

        [ 404, ['Content-Type'=>'text/plain'], 
               ["URI $uri not found or not requested as RDF"] ];
    };

    builder {
        enable "+RDF::Light", source => $model;
        $app;
    }

=cut

use Try::Tiny;
use Plack::Request;
use RDF::Trine qw(iri statement);
use RDF::Trine::Serializer;
use Carp;

use RDF::Light::Source;

use parent 'Plack::Middleware';
use Plack::Util::Accessor qw(source base formats via_param via_extension);

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

    $self->formats( \%rdf_formats ) unless $self->formats;

    # TODO: support array ref and custom serialization formats
    ref $self->formats eq 'HASH'
        or carp 'formats must be a hash reference';

    $self->via_param(1) unless defined $self->via_param;
}

sub call {
    my $self = shift;
    my $env = shift;

    my $app = $self->app;
    my $req = Plack::Request->new( $env );

    my ($type, $serializer) = $self->guess_serialization( $env );

    $env->{'rdflight.uri'} = $self->uri( $env )
        unless defined $env->{'rdflight.uri'};

    if ( $type ) {
        $env->{'rdflight.type'}       = $type;
        $env->{'rdflight.serializer'} = $serializer;

        my $rdf_data = $self->retrieve_and_serialize( $env );

        if ( defined $rdf_data ) {
            return [ 200, [ 'Content-Type' => $type ], [ $rdf_data ] ];
        }
    }

    # pass through if no/unknown serializer or empty source (URI not found) or error 
    if ( $app ) {
        return $app->( $env );
    } else {
        return [ 404, [ 'Content-Type' => 'text/plain' ], [ 'Not found' ] ];
    }
}

sub retrieve_and_serialize {
    my $self = shift;
    my $env  = shift;

    return unless defined $self->source;

    my $serializer = $env->{'rdflight.serializer'};

    my $sources = $self->source;
    $sources = [ $sources ] unless ref $sources and ref $sources eq 'ARRAY';

    foreach my $src (@$sources) {
        my $rdf; # = $self->source->retrieve($env);

        if ( UNIVERSAL::isa( $src, 'CODE' ) ) {
            $rdf = $src->($env);
        } elsif ( UNIVERSAL::isa( $src, 'RDF::Trine::Model' ) ) {
            $rdf = $src->bounded_description( iri($env->{'rdflight.uri'}) );
        } elsif ( UNIVERSAL::can( $src, 'retrieve' ) ) {
            $rdf = $src->retrieve( $env );
        }

        if ( UNIVERSAL::isa( $rdf, 'RDF::Trine::Model' ) ) { 
            if ( $rdf->size > 0 ) {
                return $serializer->serialize_model_to_string( $rdf );
            }
        } elsif ( UNIVERSAL::isa( $rdf, 'RDF::Trine::Iterator' ) ) {
            if ( $rdf->peek ) {
                return $serializer->serialize_iterator_to_string( $rdf );
            }
        } else {
            # TODO: how to indicate an error? (500?)
            # $env->{'rdflight.error'} = ... ?
        }
    }

    return;
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
    my $format;

    if ($self->via_param and $req->param('format')) {
        $format = $req->param('format');
    } elsif ($self->via_extension) {
        my $path = $env->{PATH_INFO} || '';
        if ( $path =~ /^(.*)\.([^.]+)$/ and $possible_formats->{$2} ) {
            $env->{PATH_INFO} = $1;
            $format = $2;
        }
    }    

    my ($type, $serializer);

    if ($format) {
        my $name = $possible_formats->{$format};
        if ($name) { try {
            $serializer = RDF::Trine::Serializer->new( $name );
            ($type) = $serializer->media_types;
        } } # TODO: catch if unknown format or format not available
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

sub uri { 
    my $env = shift;

    return $env->{'rdflight.uri'} if defined $env->{'rdflight.uri'};

    my ($base, $self); # TODO: support as second argument

    if (UNIVERSAL::isa($env,'RDF::Light')) {
        ($self, $env) = ($env, shift);
        $base = $self->base;
    }

    # TODO: more rewriting based on Plack::App::URLMap
    
    my $req = Plack::Request->new( $env );

    $base = defined $base ? $base : $req->base;

    my $path = $req->path;
    $path =~ s/^\///;
    return $base.$path;
}

=head1 INTRODUCTION

This package provides a PSGI application to serve RDF as Linked Data. In
contrast to other Linked Data applications, URIs must not have query parts and
the distinction between information-resources and non-information resources is
disregarded (some Semantic Web evangelists may be angry about this). By now
this package is experimental. For a more complete package see
L<RDF::LinkedData>.

The package implements a PSGI application that can be used as
L<Plack::Middleware> to provide RDF data. The implementation is based on
L<RDF::Trine> which is a full implementation of RDF standards in Perl.

=head1 OVERVIEW

An RDF::Light application processes PSGI/HTTP requests in three steps:

=over 4

=item 1

Determine query URI and serialization format (mime type) and set the request
variables C<rdflight.uri>, C<rdflight.type>, and C<rdflight.serializer>.

=item 2

Retrieve data about the resource which is identified by the request URI.

=item 3

Create a serialization.

=back

=head1 METHODS

=head2 new ( [ %configuration ] )

Creates a new object.

=head2 CONFIGURATION

=over 4

=item source

Sets a L<RDF::Trine::Model> or a code reference as RDF source that returns a 
Model or Iterator (see L<RDF::Light::Source>) to query from. You can also set 
an array reference with a list of multiple sources, which are cascaded.

For testing you can use the function dummy_source that always returns a single
triple and is exported by RDF::Light::Source.

=item base

Maps request URIs to a given URI prefix, similar to L<Plack::App::URLMap>.

For instance if you deploy you application at C<http://your.domain/> and set
base to C<http://other.domain/> then a request for C<http://your.domain/foo> 
is be mapped to the URI C<http://other.domain/foo>.

=item formats

Defines supported serialization formats. You can either specify an array 
reference with serializer names or a hash reference with mappings of format 
names to serializer names. Serializer names must exist in
RDF::Trine's L<RDF::Trine::Serializer>::serializer_names.

  RDF::Light->new ( formats => [qw(ntriples rdfxml turtle)] )

  RDF::Light->new ( formats => {
      nt  => 'ntriples',
      rdf => 'rdfxml',
      xml => 'rdfxml',
      ttl => 'turtle'
  } );

By default the formats rdf, xml, and rdfxml (for L<RDF::Trine::Serializer>),
ttl (for L<RDF::Trine::Serializer::Turtle>), json 
(for L<RDF::Trine::Serializer::RDFJSON>), and nt 
(for L<RDF::Trine::Serializer::NTriples>) are used.

=item via_param

Detect serialization format via 'format' parameter. For instance
C<foobar?format=ttl> will serialize URI foobar in RDF/Turtle.
This is enabled by default.

=item via_extension

Detect serialization format via "file extension". For instance
C<foobar.rdf> will serialize URI foobar in RDF/XML.
This is disabled by default.

=item extensions

Enable file extensions (not implemented yet).

    http://example.org/{id}
    http://example.org/{id}.html
    http://example.org/{id}.rdf
    http://example.org/{id}.ttl

=back

=head2 guess_serialization ( $env )

Given a PSGI request this function checks whether an RDF serialization format
has been B<explicitly> asked for, either by HTTP content negotiation or by
format query parameter or by file extension. You can call this as method or
as function and export it on request.

=head1 FUNCTIONS

=head2 uri ( $env )

Returns a request URI as string. The request URI is either taken from
C<$env->{'rdflight.uri'}> (if defined) or constructed from request's base 
and path. Query parameters are ignored.

=cut

=head2 SEE ALSO

See also L<RDF::Light::Graph>, which is bundled with this module.

=head2 ACKNOWLEDGEMENTS

This package is actually a very thin layer on top of existing packages such as
L<RDF::Trine>, L<Plack>, and L<Template>. Theirs authors deserve all thanks.

=cut

1;
