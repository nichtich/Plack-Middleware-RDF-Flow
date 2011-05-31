use Test::More;
use Plack::Test;
use Plack::Builder;
use HTTP::Request;
use Data::Dumper;
use Try::Tiny;
use RDF::Light;
use RDF::Light::Source;

use strict;
use warnings;

BEGIN {
    use lib "t";
    require_ok "app_tests.pl"; 
}

my $not_found = sub { [404,['Content-Type'=>'text/plain'],['Not found']] };

my $app = builder {
    enable "+RDF::Light", source => \&dummy_source;
    $not_found;
};

app_tests
    app => $app,
    tests => [{
        name    => 'Nobody asked for RDF',
        request => [ GET => '/example' ],
        headers => { 'Content-Type' => 'text/plain' },
        content => 'Not found',
        code    => 404,
    },{
        name    => 'request format=ttl',
        request => [ GET => '/example?format=ttl' ],
        content => qr{example> a <http://www.w3.org/2000/01/rdf-schema#Resource>},
        headers => { 'Content-Type' => 'application/turtle' },
    },
    ( map { {
        name    => "request accept: $_",
        request => [ GET => '/example', [ 'Accept' => "$_,text/plain" ] ],
        headers => { 'Content-Type' => $_ },
        content => qr{example> a <http://www.w3.org/2000/01/rdf-schema#Resource>},
      } } qw(text/turtle application/x-turtle application/turtle)
    )
    # TODO mime-type=..., file extension
    ,{
        name    => 'request accept: application/rdf+xml',
        request => [ 'GET', '/', [ 'Accept' => 'application/rdf+xml' ] ],
        headers => { 'Content-Type' => 'application/rdf+xml', },
    }];

$app = builder {
    enable "+RDF::Light"; # empty_source
    $not_found;
};

app_tests 
    app => $app,
    tests => [{
        name    => 'nobody asked for RDF',
        request => [ GET => '/example' ],
        headers => { 'Content-Type' => 'text/plain' },
        content => 'Not found',
        code    => 404,
    },{
        name    => 'request format=ttl',
        request => [ GET => '/example?format=ttl' ],
        headers => { 'Content-Type' => 'text/plain' },
        content => 'Not found',
        code    => 404,
    }];

done_testing;
