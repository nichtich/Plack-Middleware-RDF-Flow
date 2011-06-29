use strict;
use warnings;

use lib 't';
use TestPlackApp;

use Test::More;
use Plack::Test;
use Plack::Builder;
use RDF::Light;
use RDF::Light::Source qw(union dummy_source);
use RDF::Trine::Model;
use RDF::Trine qw(iri statement);

my $not_found = sub { [404,['Content-Type'=>'text/plain'],['Not found']] };

my $example_model = RDF::Trine::Model->temporary_model;
$example_model->add_statement(statement( 
    map { iri("http://example.com/$_") } qw(subject predicate object) ));

test_app
    name => "RDF::Trine::Model as source",
    app => builder {
        enable "+RDF::Light", 
            base => "http://example.com/", 
            source => $example_model;
        $not_found;
    },
    tests => [{
        request => [ 'GET', '/subject', [ 'Accept' => 'text/turtle' ] ],
        content => qr{subject>.+predicate>.+object>},
        code    => 200,
    },{
        request => [ 'GET', '/adverb', [ 'Accept' => 'text/turtle' ] ],
        content => 'Not found',
        code    => 404,
    }];
 
test_app
    name => "Array of sources",
    app => builder {
        enable "+RDF::Light", 
            base => "http://example.com/", 
            source => union( $example_model, \&dummy_source );
        $not_found;
    },
    tests => [{
        request => [ 'GET', '/subject', [ 'Accept' => 'text/turtle' ] ],
        content => qr{subject>.+predicate>.+object>},
        code    => 200,
    },{
        request => [ 'GET', '/adverb', [ 'Accept' => 'text/turtle' ] ],
        content => qr{adverb> a.+Resource>},
        code    => 200,
    }];

my $source = sub { die "boo!"; };

test_app 
    name => 'Failing source',
    app => RDF::Light->new( base => "http://example.com/", source => $source ),
    tests => [{
        request => [ 'GET', '/foo', [ 'Accept' => 'text/turtle' ] ],
        content => 'boo!',
        code    => 500,
    }];

test_app 
    name => 'Empty source',
    app => RDF::Light->new( base => "http://example.com/", source => sub { } ),
    tests => [{
        request => [ 'GET', '/foo', [ 'Accept' => 'text/turtle' ] ],
        code    => 404,
    }];

$source = MySource->new;

test_app 
    name => "Module as source",
    app => RDF::Light->new( base => "http://example.com/", source => $source ),
    tests => [{
        request => [ 'GET', '/foo', [ 'Accept' => 'text/turtle' ] ],
        content => qr{foo> a.+Resource>},
        code    => 200,
    }];

done_testing;

package MySource;
use base 'RDF::Light::Source';
use RDF::Light::Source;

#sub new { bless {}, shift; }
sub call { dummy_source( $_[1] ) }

1;
