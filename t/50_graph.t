use strict;
use warnings;

use Test::More;
use RDF::Trine qw(iri literal blank statement);
use RDF::Trine::NamespaceMap;
use RDF::Trine::Parser;
use Data::Dumper;

use_ok 'RDF::Light::Graph';

my $graph = RDF::Light::Graph->new;
isa_ok $graph, 'RDF::Light::Graph';

my $lit = $graph->node( literal("Geek & Poke") );
isa_ok $lit, 'RDF::Light::Node::Literal';
ok ($lit->is_literal && !$lit->is_resource && !$lit->is_blank, 'is_literal');
is $lit->str, 'Geek & Poke', 'stringify literal';
is $lit->esc, 'Geek &amp; Poke', 'HTML escape literal';
is $lit->type, undef, 'untyped literal';

is $graph->literal("Geek & Poke")->str, $lit->str, 'construct via ->literal';

diag('language tags');
my $l1 = $graph->literal("bill","en-GB");
my $l2 = $graph->literal("check","en-US");
is "$l1", "bill", 'literal with language code';
is $l1->lang, 'en-gb';
is $l2->lang, 'en-us'; 
ok $l1->is_en_gb && !$l2->is_en_gb, 'is_en_gb';
ok !$l1->is_en_us && $l2->is_en_us, 'is_en_us';
ok $l1->is_en_ && $l2->is_en_ && !$l1->is_en, 'is_en_';
ok $l1->is('@') && $l1->is('@en-'), 'is(...)';

$l1 = $graph->literal("love","en");
ok $l1->is_en && $l1->is_en_, 'is_en_ and is_en';


diag('blank nodes');
my $blank = $graph->node( blank('x1') );
isa_ok $blank, 'RDF::Light::Node::Blank';
ok (!$blank->is_literal && !$blank->is_resource && $blank->is_blank, 'is_blank');
is $blank->id, 'x1', 'blank id';

is $graph->blank("x1")->id, $blank->id, 'construct via ->blank';
is RDF::Light::Node::Blank->new( $graph, 'x1' )->id, $blank->id, 'blank constructor';

# TODO: test accessing properties of blank nodes

diag('resource nodes');
my $uri = $graph->node( iri('http://example.com/"') );
isa_ok $uri, 'RDF::Light::Node::Resource';
ok (!$uri->is_literal && $uri->is_resource && !$uri->is_blank, 'is_resource');
is "$uri", 'http://example.com/"', 'stringify URI';
is $uri->href, 'http://example.com/&quot;', 'HTML escape URI';
is $uri->esc,  'http://example.com/&quot;', 'HTML escape URI';

is $graph->resource('http://example.com/"')->uri, $uri->uri, 'construct via ->resource';

my $map  = RDF::Trine::NamespaceMap->new({
  foaf => iri('http://xmlns.com/foaf/0.1/'),
  ''   => iri('http://example.org/')
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

$obj = $a->zonk;
is_deeply( "$obj", 'foo', 'property with default namespace');

is $graph->node('alice')->uri, 'http://example.org/alice';
is $graph->bob->foaf_name->str, 'Bob', 'chaining accesors';

is $graph->foaf_name->uri, 'http://xmlns.com/foaf/0.1/name', 'namespace URI';
is $graph->foaf__name->uri, 'http://example.org/foaf_name', 'non-namespace URI';

$graph->add( statement(
  iri('http://example.org/alice'),
  iri('http://example.org/zonk'),
  literal('bar','fr'),
));

$obj = $a->zonk('@fr');
is_deeply( "$obj", 'bar', 'property with filter');

# TODO:
# $obj = $a->zonk('@fr','');
# is_deeply( "$obj", 'bar', 'property with filter');

# TODO: Test dumper
my $d = $a->turtle;
ok $d, 'has dump';

done_testing;

__DATA__
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix x: <http://example.org/> .
<http://example.org/alice> foaf:knows <http://example.org/bob> .
<http://example.org/bob>   foaf:knows <http://example.org/alice> .
<http://example.org/alice> foaf:name "Alice" .
<http://example.org/bob>   foaf:name "Bob" .
<http://example.org/alice> x:zonk "foo"@en .

