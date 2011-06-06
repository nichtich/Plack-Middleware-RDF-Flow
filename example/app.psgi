use strict;
use warnings;

# Experimental PSGI app for testing RDF::Light modules
# This source code is ugly because it is work in progress

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
    my ($code, $msg, $content) = (404,"URI $uri not found");

    $env->{'psgix.logger'}->({ level => "info", message => "APP" });

    my $iterator = $model->get_statements( iri($uri), undef, undef );

    if ($iterator->peek) {
        $code = 200;
        my $graph = RDF::Light::Graph->new( namespaces => $ns );
        $graph->add( $iterator );
        my $vars = { uri => $graph->node(iri($uri)), formats => [qw(json ttl rdf)] };
        my $out = "";

        if ( $tt->process("country.html", $vars, \$out) ) {
            $content = $out;
            utf8::downgrade($content);
        } else {
            $code = 500;
            $msg = $tt->error->as_string;
        }
    }

    if (!$content) {
        $content = <<HTML
<html><head></head><body>
<p>$msg</p>
</body>
HTML
    }

    return [ $code, ['Content-Type'=>'text/html'], [ $content ] ];
};

# inline middleware
my $index_app = sub {
    my $app = shift;
    sub {
        my $env = shift;
        my $uri = RDF::Light::uri($env);
        my $content = "";

        $env->{'psgix.logger'}->({ level => "info", message => "Index with $uri and $base" });

        return $app->($env) unless $uri eq $base;

        my $graph = RDF::Light::Graph->new( namespaces => $ns, model => $model );
        my $vars = { 
            #uri => $graph->node(iri($base)), 
            countries => []
        };

        my $iterator = $model->get_statements( undef, $ns->uri('rdfs:type'), $ns->namespace_uri('')->Country );

        while (my $st = $iterator->next) {
           push @{$vars->{countries}}, $graph->node( $st->subject );
        }

        # TODO: error handling (use Plack::Middleware::TemplateToolkit
        $tt->process("index.html", $vars, \$content);
        utf8::downgrade($content);
        
        $env->{'psgix.logger'}->({ level => "info", message => "Index done" });
        return [ 200, ['Content-Type' => 'text/html'], [$content]];
    };
};

builder {
    enable 'SimpleLogger';
    enable 'JSONP'; # for RDF/JSON in AJAX
    enable 'Debug';
    enable "+RDF::Light", source => $model, base => $base;
    enable $index_app;
    $app;
};

