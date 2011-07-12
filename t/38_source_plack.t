use strict;
use warnings;

use Test::More;
use Test::RDF;
use RDF::Light;
use RDF::Trine qw(statement iri);
use RDF::Light::Source qw(source);

sub query { { HTTP_HOST => 'example.org', PATH_INFO => shift }; }
sub model { 
    my $m = RDF::Trine::Model->new;
    $m->add_statement(statement( iri(shift), iri(shift), iri(shift) )) while @_;
	$m; }

sub foo { model( RDF::Light::uri( shift ), 'x:a', 'y:bar' ); };

my $src = RDF::Light::Source->new( \&foo );

my $env = query('/hello'); 
my $rdf = $src->retrieve($env);

isa_ok( $rdf, 'RDF::Trine::Model' );
# use RDF::Dumper; print rdfdump($rdf)."\n";

# TODO: test use as middleware

done_testing;
