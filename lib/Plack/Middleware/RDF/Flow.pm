use strict;
use warnings;
package Plack::Middleware::RDF::Flow;
#ABSTRACT: Simplified Linked Data provider

use Log::Contextual::WarnLogger;
use Log::Contextual qw(:log), -default_logger
    => Log::Contextual::WarnLogger->new({ env_prefix => __PACKAGE__ });

use Try::Tiny;
use Scalar::Util qw(blessed);
use Plack::Request;
use RDF::Trine qw(0.135 iri statement);
use RDF::Trine::Serializer;
use RDF::Trine::NamespaceMap;
use RDF::Flow qw(rdflow rdflow_uri);
use Encode;
use Carp;

use parent 'Exporter', 'Plack::Middleware';

use Plack::Util::Accessor qw(source base formats via_param via_extension 
    namespaces pass_through empty_base);

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

    $self->source( rdflow( $self->source || sub { } ) );

    $self->via_param(1) unless defined $self->via_param;

    $self->namespaces( RDF::Trine::NamespaceMap->new )
        unless $self->namespaces;
}

sub call {
    my $self = shift;
    my $env = shift;

    my $app = $self->app;
    my $req = Plack::Request->new( $env );

    my ($type, $serializer) = $self->guess_serialization( $env );

    # TODO: put uri into another module?
    $env->{'rdflow.uri'} = $self->uri( $env )
        unless defined $env->{'rdflow.uri'};

    if ( $type ) {
        $env->{'rdflow.type'}       = $type;
        $env->{'rdflow.serializer'} = $serializer;

        my $rdf = $self->_retrieve( $env );

        if ( $env->{'rdflow.error'} ) {
            return [ 500, [ 'Content-Type' => 'text/plain' ], [ $env->{'rdflow.error'} ] ];
        }

        my $rdf_data;

        if ( UNIVERSAL::isa( $rdf, 'RDF::Trine::Model' ) ) { 
            $rdf_data = $serializer->serialize_model_to_string( $rdf );
        } elsif ( UNIVERSAL::isa( $rdf, 'RDF::Trine::Iterator' ) ) { 
            $rdf_data = $serializer->serialize_iterator_to_string( $rdf );
        }

        if ( defined $rdf_data ) {
            $rdf_data = encode('utf8',$rdf_data);
            return [ 200, [ 'Content-Type' => $type ], [ $rdf_data ] ];
        }
    } elsif ( $self->pass_through ) {
        my $rdf = $self->_retrieve( $env );
        $env->{'rdflow.data'} = $rdf;
    }

    # pass through if no/unknown serializer or empty source (URI not found) or error 
    if ( $app ) {
        return $app->( $env );
    } else {
        return [ 404, [ 'Content-Type' => 'text/plain' ], [ 'Not found' ] ];
    }
}

=head2 retrieve ( $env )

Given a L<PSGI> environment, this method queries the source(s) for a 
requested URI (if given) and either returns undef or a non-empty
L<RDF::Trine::Model> or L<RDF::Trine::Iterator>. On error this method
does not die but sets the environment variable rdflow.error. Note that
if there are multiple source, there may be both an error, and a return 
value.

=cut
sub _retrieve {
    my ($self,$env) = @_;

    rdflow_uri( $env );

    if (!$self->empty_base and $env->{'rdflow.uri'} eq ($self->base||'')) {
        log_trace { "empty base" };
        return RDF::Trine::Model->new;
    }

    my $src = $self->source;

    log_trace { 'Retrieve from source' };
    my $rdf = $src->retrieve( $env );
    #  my $rdf = try {
    #   my $rdf = $src->retrieve( $env );
        #} catch {
        #    $_ =~ s/ at.+ line \d+.?\n?//; # TODO: is there a cleaner way?
        #    $env->{'rdflow.error'} = $_;
        #    RDF::Trine::Model->new;
        #};

        #return unless defined $rdf;

    #   if ( UNIVERSAL::isa( $rdf, 'RDF::Trine::Model' ) ) { 
    #       $rdf if $rdf->size > 0;
    #   } elsif ( UNIVERSAL::isa( $rdf, 'RDF::Trine::Iterator' ) ) {
    #       return $rdf if $rdf->peek;
    #   } else {
    #       $env->{'rdflow.error'} = 'Invalid source';
    #   }
    return $rdf;
}

sub guess_serialization {
    my $env = shift;
    my ($self, $possible_formats);

    if (blessed $env and $env->isa('Plack::Middleware::RDF::Flow')) {
        ($self, $env) = ($env, shift);
        $possible_formats = $self->formats;
    } else {
        $possible_formats = \%rdf_formats; 
    }

    # TODO: check $env{rdflow.type} / $env{rdflow.serializer}

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
            my $namespaces = $self->namespaces;
            $serializer = RDF::Trine::Serializer->new( $name, namespaces => $namespaces );
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

    log_trace { "Guessed serialization $type with " . ref($serializer) };

    return ($type, $serializer);
}

sub uri { 
    my $env = shift;

    return $env->{'rdflow.uri'} if defined $env->{'rdflow.uri'};

    my ($base, $self); # TODO: support as second argument

    if (blessed $env and $env->isa('Plack::Middleware::RDF::Flow')) {
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

=head1 SYNOPSIS

    use Plack::Builder;
    use Plack::Request;
    use RDF::Flow qw(rdflow_uri);

    my $model = RDF::Trine::Model->new( ... );

    my $app = sub {
        my $env = shift;
        my $uri = rdflow_uri( $env );

        [ 404, ['Content-Type'=>'text/plain'], 
               ["URI $uri not found or not requested as RDF"] ];
    };

    builder {
        enable 'RDF::Flow',
            source => $model;
        $app;
    }

=cut


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

An RDF::Flow application processes PSGI/HTTP requests in three steps:

=over 4

=item 1

Determine query URI and serialization format (mime type) and set the request
variables C<rdflow.uri>, C<rdflow.type>, and C<rdflow.serializer>.

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
Model or Iterator (see L<RDF::Flow>) to query from. You can also set 
an array reference with a list of multiple sources, which are cascaded.

For testing you can use the function dummy_source that always returns a single
triple and can be exported by RDF::Flow.

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

  Plack::Middleware::RDF::Flow->new ( formats => [qw(ntriples rdfxml turtle)] )

  Plack::Middleware::RDF::Flow->new ( formats => {
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
C<$env->{'rdflow.uri'}> (if defined) or constructed from request's base 
and path. Query parameters are ignored.

=cut

=head2 SEE ALSO

See also L<RDF::Lazy>.

To test you applications you should use L<Test::RDF>.

=head2 ACKNOWLEDGEMENTS

This package is actually a very thin layer on top of existing packages such as
L<RDF::Trine>, L<Plack>, and L<Template>. Theirs authors deserve all thanks.

=cut

1;
