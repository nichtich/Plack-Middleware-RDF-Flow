use strict;
use warnings;

use Test::More;
use Test::RDF;
use RDF::Light;
use RDF::Trine qw(statement iri);
use RDF::Light::Source qw(source);
use RDF::Light::Source::Union;
use RDF::Light::Source::Cascade;
use RDF::Light::Source::Pipeline;

my ($src, $rdf, $env);

sub foo { 
    my $uri = RDF::Light::uri( shift );
    $uri =~ /[a-z]$/ ? model( $uri , 'x:a', 'y:foo') : model();
};
sub bar { model( RDF::Light::uri( shift ), 'x:a', 'y:bar'); };

my $foo = source \&foo;
my $bar = source \&bar;

my $empty = source sub { model(); };
my $nil   = source sub { undef; };

$src = RDF::Light::Source::Union->new( $empty, $foo, $foo, $nil, undef, \&bar );

$rdf = $src->retrieve( query('/foo') );
ok($rdf);

isomorph_graphs( $rdf, model(qw(
http://example.org/foo x:a y:foo 
http://example.org/foo x:a y:bar)), 'union' );

$src = RDF::Light::Source::Cascade->new( $empty, $foo, \&bar );
$rdf = $src->retrieve( query('/foo') );
isomorph_graphs( $rdf, model(qw(http://example.org/foo x:a y:foo)), 'cascade' );

$src = cascade( $empty, \&bar, $foo );
$rdf = $src->retrieve( query('/foo') );
isomorph_graphs( $rdf, model(qw(http://example.org/foo x:a y:bar)), 'cascade' );

$env = query('/hi');
$src = pipeline( $foo, $bar );
$rdf = $src->retrieve( $env );
isomorph_graphs( $rdf, model(qw(http://example.org/hi x:a y:bar)), 'pipeline' );
is( $rdf, $env->{'rdflight.data'}, 'pipeline sets rdflight.data' );

$src = pipeline( $foo, $bar, $empty );
$rdf = $src->retrieve( query('/hi') );
isomorph_graphs( $rdf, model(), 'empty source nils pipeline' );

# pipeline as conditional: if $foo has content then union of $foo and $bar
$src = $foo->pipe_to( union( previous, $bar ) );
$rdf = $src->retrieve( query('/abc') );
isomorph_graphs( $rdf, model(qw(
http://example.org/abc x:a y:foo 
http://example.org/abc x:a y:bar)), 'conditional' );

$rdf = $src->retrieve( query('/1') );
    
isomorph_graphs( $rdf, model(), 'conditional' );

done_testing;

# helper methods to create models and iterators
sub model { 
    my $m = RDF::Trine::Model->new;
    $m->add_statement(statement( iri(shift), iri(shift), iri(shift) )) while @_;
	$m; }

sub iterator { model(@_)->as_stream; }

sub query { { HTTP_HOST => 'example.org', PATH_INFO => shift }; }

