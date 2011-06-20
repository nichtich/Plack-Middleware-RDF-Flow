use strict;
use warnings;

use Test::More;
use Test::RDF;
use RDF::Light;
use RDF::Trine qw(statement iri);
use RDF::Light::Source qw(source);
use RDF::Light::Source::Union;
use RDF::Light::Source::Cascade;

my ($src,$rdf,$env);

sub foo { 
    my $uri = RDF::Light::uri( shift );
    model ($uri, 'x:a', 'y:foo');
};
my $foo = source \&foo;
sub bar {
    my $uri = RDF::Light::uri( shift );
    model ($uri, 'x:a', 'y:bar');
};

my $empty = source sub { model(); };
my $nil   = source sub { undef; };

$env = { HTTP_HOST => 'example.org', PATH_INFO => '/foo' };

$src = RDF::Light::Source::Union->new( $empty, $foo, $foo, $nil, undef, \&bar );

$rdf = $src->retrieve( $env );
ok($rdf);

isomorph_graphs( $rdf, model(qw(
http://example.org/foo x:a y:foo 
http://example.org/foo x:a y:bar)), 'union' );


$src = RDF::Light::Source::Cascade->new( $empty, $foo, \&bar );
$rdf = $src->retrieve( $env );
isomorph_graphs( $rdf, model(qw(http://example.org/foo x:a y:foo)), 'cascade' );

$src = cascade( $empty, \&bar, $foo );
$rdf = $src->retrieve( $env );
isomorph_graphs( $rdf, model(qw(http://example.org/foo x:a y:bar)), 'cascade' );

done_testing;

# helper methods to create models and iterators
sub model { 
    my $m = RDF::Trine::Model->new;
    $m->add_statement(statement( iri(shift), iri(shift), iri(shift) )) while @_;
	$m; }
sub iterator { model(@_)->as_stream; }

