use strict;
use warnings;

# Experimental PSGI app to test:
use RDF::Light;
use RDF::Light::Graph;

use Plack::Builder;
use Plack::Request;

use File::Spec;
use File::Basename;
use Cwd;
use CGI qw(escapeHTML);

use RDF::Trine qw(iri);
use RDF::Trine::NamespaceMap;

use Template;

my $dir  = Cwd::realpath( dirname($0) );
my $file = File::Spec->catfile( $dir, 'countries.rdf' );
my $tt = Template->new( INCLUDE_PATH => $dir );

my $base = 'http://downlode.org/rdf/iso-3166/countries#';
my $model = RDF::Trine::Model->new("Memory;file:$file");

my $ns = RDF::Trine::NamespaceMap->new({
   rdfs    => iri('http://www.w3.org/1999/02/22-rdf-syntax-ns#'),
   ''      => iri('http://downlode.org/rdf/iso-3166/schema#'),
   country => iri('http://downlode.org/rdf/iso-3166/countries#'),
});

my $app = sub {
    my $env = shift;
    my $uri = RDF::Light::uri($env);
    my ($code, $msg) = (404,"URI $uri not found");

#    $env->{'psgix.logger'}->({ level => "warn", message => "Hallo" });

    my $iterator = $model->get_statements( iri($uri), undef, undef );

    if ($iterator->peek) {
        $code = 200;
        my $graph = RDF::Light::Graph->new( namespaces => $ns );
        $graph->add( $iterator );
        my $vars = { uri => $graph->node(iri($uri)) };
        my $out = "";

        if ( $tt->process("country.html", $vars, \$out) ) {
            $msg = $out;
            utf8::downgrade($msg);
        } else {
            $code = 500;
            $msg = $tt->error->as_string;
        }
    }

    return [ $code, ['Content-Type'=>'text/html'], [ $msg ] ];
};

builder {
    enable "SimpleLogger";
    enable "+RDF::Light", source => $model, base => $base;
    $app;
};
