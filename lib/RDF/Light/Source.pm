use strict;
use warnings;
package RDF::Light::Source;

use Plack::Request;
use RDF::Trine qw(iri statement);

=head1 DESCRIPTION

A Source is a code reference that gets HTTP requests and returns RDF models.
This is similar to L<PSGI> applications, which return HTTP responses. In 
contrast to a PSGI application, a source must return an object of type 
L<RDF::Trine::Model> or L<RDF::Trine::Iterator>.

In general you do not need to directly use this package. Just create a source
as code reference like one of the following examples:

    my $source = sub {
        my $env = shift;

        my $model = RDF::Trine::Model->temporary_model;

        add_some_statements( $model );

        return $model
    };

    my $source = sub {
        my $env = shift;

        my $query    = build_some_query_from( $env ); 
        my $iterator = query_model_for_some_triples( $model, $query );

        return $model
    };

This package contains several functions that are exported by default:

=over 4

=item empty_source

This source always returns an empty model.

=item dummy_source

This source returns a single triple such as the following, based on the
request URI. The request URI is either taken from the PSGI request variable
'rdflight.uri' or build from the request's base and path:

    <http://example.org/your/request> rdf:type rdfs:Resource .

=item model_source ( $model )

This function returns a source that returns a bounded description from a 
model (see L<RDF::Trine::Model>) for a given request URI.

=cut

use parent 'Exporter';
our @EXPORT = qw(dummy_source empty_source model_source);

our $rdf_type = iri('http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
our $rdfs_resource = iri('http://www.w3.org/2000/01/rdf-schema#Resource');

sub dummy_source {
    my $env = shift;
    my $uri = RDF::Light::uri( $env );

    my $model = RDF::Trine::Model->temporary_model;
    $model->add_statement( statement( iri($uri), $rdf_type, $rdfs_resource ) );

    return $model;
}

sub empty_source {
    return RDF::Trine::Model->temporary_model;
}

sub model_source {
    my $model = shift;

    sub {
        my $env = shift;
        my $uri = RDF::Light::uri( $env );

print "------URI: ".$uri."\n";

        return $model->bounded_description( iri($uri) );
    }
}

1;
