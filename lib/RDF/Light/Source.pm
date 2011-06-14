use strict;
use warnings;
package RDF::Light::Source;

use Plack::Request;
use RDF::Trine qw(iri statement);

use parent 'Exporter';
use Carp;
our @EXPORT = qw(dummy_source);

our $rdf_type      = iri('http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
our $rdfs_resource = iri('http://www.w3.org/2000/01/rdf-schema#Resource');

sub dummy_source {
    my $env = shift;
    my $uri = RDF::Light::uri( $env );

    my $model = RDF::Trine::Model->temporary_model;
    $model->add_statement( statement( iri($uri), $rdf_type, $rdfs_resource ) );

    return $model;
}

sub retrieve {
    return RDF::Trine::Model->temporary_model;
}

1;

__END__

=head1 DESCRIPTION

A Source is a code reference that gets HTTP requests and returns RDF models.
This is similar to L<PSGI> applications, which return HTTP responses. In 
contrast to a PSGI application, a source must return an object of type 
L<RDF::Trine::Model> or L<RDF::Trine::Iterator>.

In general you do not need to directly use this package. You can use any
of the following three as source: a code reference, an object that supports
the method 'retrieve', or an instance of RDF::Trine::Model:

    # 1. code reference

    my $source = sub {
        my $env = shift;
        my $model = RDF::Trine::Model->temporary_model;
        add_some_statements( $model );
        return $model;
    };

    # 2. object with 'retrieve' method (duck typing)

    package MySource;
    use parent 'Exporter';
    
    sub retrieve {
        my ($self, $env) = @_;
        my $query    = $self->build_query_from( $env ); 
        my $iterator = $self->get_triples_from( $query );
        return $iterator; # or model
    }

    # ...end of package, in your application just use:
    
    use MySource;
    my $source = MySource->new( ... );

    # 3. model instance

    my $model = RDF::Trine::Model->new( ... );
    my $source = $model; # RDF::Light will call $model->bounded_description

This package contains the following function which is exported by default:

=over 4

=item dummy_source

This source returns a single triple such as the following, based on the
request URI. The request URI is either taken from the PSGI request variable
'rdflight.uri' or build from the request's base and path:

    <http://example.org/your/request> rdf:type rdfs:Resource .

=cut
