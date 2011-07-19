use strict;
use warnings;

use lib 't';
use TestPlackApp;

use Test::More;
use RDF::Light;
use RDF::Source qw(dummy_source);

my $app = RDF::Light->new( 
    source => \&dummy_source
);

test_app
    app   => $app,
    tests => [{
        name    => 'request format=ttl',
        request => [ GET => '/example?format=ttl' ],
        content => qr{example> a <http://www.w3.org/2000/01/rdf-schema#Resource>},
        headers => { 'Content-Type' => 'application/turtle' },
    }];

$app = RDF::Light->new( 
    source => \&dummy_source,
    formats => { rdf => 'rdfxml' }
);

test_app
    name  => 'selected formats',
    app   => $app,
    tests => [{
        request => [ GET => '/example?format=rdf' ], code => 200
    },{
        request => [ GET => '/example?format=ttl' ], code => 404
    }];

$app = RDF::Light->new( 
    source => \&dummy_source,
    via_param => 0,
    via_extension => 1
);

test_app
    name => 'format_extension',
    app  => $app,
    tests => [{
        request => [ GET => '/example?format=ttl' ], code => 404
    },{
        request => [ GET => '/example.ttl' ], code => 200,
        content => qr{example> a <http://www.w3.org/2000/01/rdf-schema#Resource>},
    },{
        request => [ GET => '/example.ttl.ttl' ], code => 200,
        content => qr{example.ttl> a <http://www.w3.org/2000/01/rdf-schema#Resource>},
    },{
        request => [ GET => '/example.ttl?format=rdf' ], code => 200,
        content => qr{example> a <http://www.w3.org/2000/01/rdf-schema#Resource>},
    }];


$app = RDF::Light->new( 
    source => \&dummy_source,
    via_param => 1,
    via_extension => 1
);

test_app
    name => 'format_extension',
    app  => $app,
    tests => [{
        request => [ GET => '/example?format=ttl' ], code => 200,
        headers => { 'Content-Type' => 'application/turtle' },
    },{
        request => [ GET => '/example.rdfxml' ], code => 200,
        headers => { 'Content-Type' => 'application/rdf+xml' },
    },{
        request => [ GET => '/example.ttl?format=rdf' ], code => 200,
        headers => { 'Content-Type' => 'application/rdf+xml' },
    }];


done_testing;
