use strict;
use warnings;

use Test::More;
use RDF::Trine qw(iri literal blank);
use RDF::Trine::NamespaceMap;
use RDF::Trine::Parser;

use_ok 'RDF::Light::Graph';

my $graph = RDF::Light::Graph->new;
isa_ok $graph, 'RDF::Light::Graph';

my $lit = $graph->node( literal("Geek & Poke") );
isa_ok $lit, 'RDF::Light::Node::Literal';
is $lit->str, 'Geek & Poke', 'stringify literal';
is $lit->esc, 'Geek &amp; Poke', 'HTML escape literal';
is $lit->type, undef, 'untyped literal';

is $graph->literal("Geek & Poke")->str, $lit->str, 'construct via ->literal';

my $l1 = $graph->literal("bill","en-GB");
my $l2 = $graph->literal("check","en-US");
is "$l1", "bill", 'literal with language code';
is $l1->lang, 'en-gb';
is $l2->lang, 'en-us'; 

my $blank = $graph->node( blank('x1') );
isa_ok $blank, 'RDF::Light::Node::Blank';
is $blank->id, 'x1', 'blank id';

is $graph->blank("x1")->id, $blank->id, 'construct via ->blank';

my $uri = $graph->node( iri('http://example.com/"') );
isa_ok $uri, 'RDF::Light::Node::Resource';
is "$uri", 'http://example.com/"', 'stringify URI';
is $uri->href, 'http://example.com/&quot;', 'HTML escape URI';
is $uri->esc,  'http://example.com/&quot;', 'HTML escape URI';

is $graph->resource('http://example.com/"')->uri, $uri->uri, 'construct via ->resource';

my $map  = RDF::Trine::NamespaceMap->new({
  foaf => iri('http://xmlns.com/foaf/0.1/')
});
my $base = 'http://example.org/';
my $model = RDF::Trine::Model->new;
my $parser = RDF::Trine::Parser->new('turtle');
$parser->parse_into_model( $base, join('',<DATA>), $model );

$graph = RDF::Light::Graph->new( namespaces => $map, model => $model );

my $obj = [ map { "$_" }
    $graph->objects( iri('http://example.org/alice'), 'foaf_knows' ) ];

is_deeply( $obj, ['http://example.org/bob'], 'resource object');
 
my $a = $graph->resource('http://example.org/alice');
$obj = $a->foaf_name;
is_deeply( "$obj", 'Alice', 'literal object');

# TODO: $graph->get('ex:alice')->{'foaf_knows'}

done_testing;

__DATA__
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
<http://example.org/alice> foaf:knows <http://example.org/bob> .
<http://example.org/bob>   foaf:knows <http://example.org/alice> .
<http://example.org/alice> foaf:name "Alice" .
<http://example.org/bob>   foaf:name "Bob" .

