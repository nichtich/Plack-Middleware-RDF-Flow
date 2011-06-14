use strict;
use warnings;

use Test::More;
use RDF::Trine qw(iri literal);
use RDF::Trine::Model;
use RDF::Trine::Parser;
use RDF::Trine::NamespaceMap;
use Data::Dumper;
use Template;

use RDF::Light::Graph;
use Carp;

sub ttl_model {
    my $turtle = shift;
    my $base   = iri(shift || 'http://example.org/');
    my $model = RDF::Trine::Model->new;
    my $parser = RDF::Trine::Parser->new('turtle');
    $parser->parse_into_model( $base, $turtle, $model );
    return $model;
}

my $graph = RDF::Light::Graph->new;

my $vars;
my $s = $graph->literal("hallo","en");

test_tt('[% foo %]', { foo => $s }, "hallo");
test_tt('[% foo.lang %]', { foo => $s }, "en");
test_tt('[% foo.type %]', { foo => $s }, "");

my $model = ttl_model <<'TURTLE';
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
<http://example.org/alice> <http://example.org/predicate> <http://example.org/object> .
<http://example.org/alice> foaf:knows <http://example.org/bob> .
<http://example.org/bob> foaf:knows <http://example.org/alice> .
<http://example.org/alice> foaf:name "Alice" .
<http://example.org/bob> foaf:name "Bob" .
TURTLE

my $map = RDF::Trine::NamespaceMap->new({foaf => iri('http://xmlns.com/foaf/0.1/')});
$graph = RDF::Light::Graph->new( namespaces => $map, model => $model );

my $a = $graph->resource('http://example.com/"');
 
test_tt('[% a %]', { a => $a }, 'http://example.com/"', 'plain URI with quot');
test_tt('[% a.href %]', { a => $a }, 'http://example.com/&quot;', 'escaped URI with quot');

$a = $graph->resource('http://example.org/alice');
$vars = { 'a' => $a };
test_tt('[% a.foaf_name %]', $vars, 'Alice', 'single literal property');
test_tt('[% a.foaf_knows %]', $vars, 'http://example.org/bob', 'single uri property');
test_tt('[% a.foaf_knows.foaf_name %]', $vars, 'Bob', 'property chain');

# TODO: how to query literal of given language?
# x.prop('@')   # any language literal
# x.prop('^')   # any datatype'd literal
# x.prop('"')   # any literal
# x.prop(':')   # any URI
# x.prop('-')   # any blank =>  x.prop('-').id
# x.prop('@en') # english language literal

done_testing;

sub test_tt {
    my ($template, $vars, $expected, $msg) = @_;
    my $out;
    Template->new->process(\$template, $vars, \$out);
    is $out, $expected, $msg;
}

# TemplateToolkit allows for variable names containing alphanumeric characters and underscores.
# Upper case variable names are permitted, but not recommended.

__END__

