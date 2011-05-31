use Test::More;
use Plack::Test;
use Plack::Builder;
use RDF::Light;
use RDF::Light::Source;
use Data::Dumper;

use strict;
use warnings;

BEGIN {
    use lib "t";
    require_ok "app_tests.pl"; 
}

my $not_found = sub { [404,['Content-Type'=>'text/plain'],['Not found']] };

my $uri_not_found = sub {
    [ 404, ['Content-Type'=>'text/plain'], [ RDF::Light::uri(shift) ] ];
};

my $app = builder {
    enable "+RDF::Light", source => \&dummy_source;
    $uri_not_found;
};

app_tests
    app => $app,
    tests => [{
        request => [ GET => '/example' ],
        content => qr{/example$},
        code    => 404,
    },{
        request => [ GET => '/example/foo?bar=doz' ],
        content => qr{/example/foo$},
        code    => 404,
    },{
        request => [ GET => '/example?format=ttl' ],
        content => qr{^<[^>]+/example>},
        code    => 200,
    }];


for my $base ( ('http://example.org/', '', 'my:') ) {
    $app = builder {
        enable "+RDF::Light", source => \&dummy_source, base => $base;
        $uri_not_found;
    };

    app_tests
        app => $app,
        name => "Rewrite request URIs with base '$base'",
        tests => [{
            request => [ GET => '/example' ],
            content => $base."example",
            code    => 404,
        },{
            request => [ GET => '/example/foo?bar=doz' ],
            content => $base."example/foo",
            code    => 404,
        },{
            request => [ GET => '/example?format=ttl' ],
            content => qr{^<${base}example>},
            code    => 200,
        }];
}

done_testing;
