# NAME

Plack::Middleware::RDF::Flow - Serve RDF as Linked Data for RDF::Flow

# VERSION

version 0.171

# SYNOPSIS

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
        enable 'RDF::Flow', source => $model;
        $app;
    }

# DESCRIPTION

This [Plack::Middleware](http://search.cpan.org/perldoc?Plack::Middleware) provides a PSGI application to serve Linked Data.
An HTTP request is mapped to an URI, that is used to retrieve RDF data from
a [RDF::Trine::Model](http://search.cpan.org/perldoc?RDF::Trine::Model) or [RDF::Flow::Source](http://search.cpan.org/perldoc?RDF::Flow::Source). Depending on the request and
settings, the data is either returned in a requested serialization format or
it is passed to the next PSGI application for further processing.

In detail each request is processed as following:

- 1

Determine query URI and serialization format (mime type) and set the request
variables `rdflow.uri`, `rdflow.type`, and `rdflow.serializer`. The request
URI is either taken from `$env->{'rdflow.uri'}` (if defined) or
constructed from request's base and path. Query parameters are ignored by
default.

- 2

Retrieve data from a [RDF::Trine::Model](http://search.cpan.org/perldoc?RDF::Trine::Model) or a [RDF::Flow::Source](http://search.cpan.org/perldoc?RDF::Flow::Source) about the
resource identified by `rdflow.uri`, if a serialization format was determined
or if `pass_through` is set.

- 3

Create and return a serialization, if a serialization format was determined.
Otherwise store the retrieved RDF data in `rdflow.data` and pass to the next
application.

## CONFIGURATION

The following options can be set when creating a new object with `new`.

- source

Sets a [RDF::Trine::Model](http://search.cpan.org/perldoc?RDF::Trine::Model), a code reference, or another kind of
[RDF::Flow::Source](http://search.cpan.org/perldoc?RDF::Flow::Source) to retrieve RDF data from.  For testing you can use
[RDF::Flow::Source::Dummy](http://search.cpan.org/perldoc?RDF::Flow::Source::Dummy) which always returns a single triple.

- base

Maps request URIs to a given URI prefix, similar to [Plack::App::URLMap](http://search.cpan.org/perldoc?Plack::App::URLMap).

For instance if you deploy you application at `http://your.domain/` and set
base to `http://other.domain/` then a request for `http://your.domain/foo`
is be mapped to the URI `http://other.domain/foo`.

- rewrite

Code reference to rewrite the request URI.

- pass_through

Retrieve RDF data also if no serialization format was determined. In this case
RDF data is stored in `rdflow.data` and passed to the next layer.

- formats

Defines supported serialization formats. You can either specify an array
reference with serializer names or a hash reference with mappings of format
names to serializer names or serializer instances. Serializer names must exist
in RDF::Trine's [RDF::Trine::Serializer](http://search.cpan.org/perldoc?RDF::Trine::Serializer)::serializer_names and serializer
instances must be subclasses of [RDF::Trine::Serializer](http://search.cpan.org/perldoc?RDF::Trine::Serializer).

  Plack::Middleware::RDF::Flow->new ( formats => [qw(ntriples rdfxml turtle)] )

  # Plack::Middleware::RDF::Foo
  my $fooSerializer = Plack::Middleware::RDF->new( 'foo' );

  Plack::Middleware::RDF::Flow->new ( formats => {
      nt  => 'ntriples',
      rdf => 'rdfxml',
      xml => 'rdfxml',
      ttl => 'turtle',
      foo => $fooSerializer
  } );

By default the formats rdf, xml, and rdfxml (for [RDF::Trine::Serializer](http://search.cpan.org/perldoc?RDF::Trine::Serializer)),
ttl (for [RDF::Trine::Serializer::Turtle](http://search.cpan.org/perldoc?RDF::Trine::Serializer::Turtle)), json (for
[RDF::Trine::Serializer::RDFJSON](http://search.cpan.org/perldoc?RDF::Trine::Serializer::RDFJSON)), and nt (for
[RDF::Trine::Serializer::NTriples](http://search.cpan.org/perldoc?RDF::Trine::Serializer::NTriples)) are supported.

- via_param

Detect serialization format via 'format' parameter. For instance
`foobar?format=ttl` will serialize URI foobar in RDF/Turtle.
This is enabled by default.

- via_extension

Detect serialization format via "file extension". For instance
`foobar.rdf` will serialize URI foobar in RDF/XML.
This is disabled by default.

- extensions

Enable file extensions (not implemented yet).

    http://example.org/{id}
    http://example.org/{id}.html
    http://example.org/{id}.rdf
    http://example.org/{id}.ttl

## _retrieve ( $env )

Given a [PSGI](http://search.cpan.org/perldoc?PSGI) environment, this internal (!) method queries the source(s) for
a requested URI (if given) and either returns undef or a non-empty
[RDF::Trine::Model](http://search.cpan.org/perldoc?RDF::Trine::Model) or [RDF::Trine::Iterator](http://search.cpan.org/perldoc?RDF::Trine::Iterator). On error this method does not
die but sets the environment variable rdflow.error. Note that if there are
multiple source, there may be both an error, and a return value.

# FUNCTIONS

## guess_serialization ( $env )

Given a PSGI request this function checks whether an RDF serialization format
has been __explicitly__ asked for, either by HTTP content negotiation or by
format query parameter or by file extension. You can call this as method or
as function and export it on request.

# LIMITATIONS

By now this package is experimental. Extensions are not supported yet. In
contrast to other Linked Data applications, URIs must not have query parts and
the distinction between information-resources and non-information resources is
disregarded (some Semantic Web evangelists may be angry about this).

## SEE ALSO

For a more complete package see [RDF::LinkedData](http://search.cpan.org/perldoc?RDF::LinkedData). You should always use
[Plack::Test](http://search.cpan.org/perldoc?Plack::Test) and [Test::RDF](http://search.cpan.org/perldoc?Test::RDF) to test you application.

## ACKNOWLEDGEMENTS

This package is actually a very thin layer on top of existing packages such as
[RDF::Trine](http://search.cpan.org/perldoc?RDF::Trine), [Plack](http://search.cpan.org/perldoc?Plack), and [Template](http://search.cpan.org/perldoc?Template). Theirs authors deserve all thanks.

# AUTHOR

Jakob Voß <voss@gbv.de>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Jakob Voß.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.