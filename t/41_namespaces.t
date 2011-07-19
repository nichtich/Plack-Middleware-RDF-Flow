use strict;
use warnings;

use lib 't';
use TestPlackApp;

use Test::More;
use RDF::Light;
use RDF::Source qw(dummy_source);
use RDF::Trine::NamespaceMap;

my $app = RDF::Light->new( 
    source => \&dummy_source,
    namespaces => { rdfs => 'http://www.w3.org/2000/01/rdf-schema#' },
);

ns_test();

$app->namespaces( RDF::Trine::NamespaceMap->new( {
    rdfs => 'http://www.w3.org/2000/01/rdf-schema#', 
} ) );

ns_test();

sub ns_test {
  test_app
    app   => $app,
    tests => [{
        name    => 'ttl with namespaces',
        request => [ GET => '/example?format=ttl' ],
        content => qr{example> a rdfs:Resource},
    }];
}

done_testing;
