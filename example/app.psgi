use Plack::Builder;
use Plack::Request;
use RDF::Light;

use File::Spec;
use File::Basename;
use Cwd;
use CGI qw(escapeHTML);

use RDF::Trine qw(iri);

my $dir  = Cwd::realpath( dirname($0) );
my $file = File::Spec->catfile( $dir, 'countries.rdf' );

my $base = 'http://downlode.org/rdf/iso-3166/countries#';
my $model = RDF::Trine::Model->new("Memory;file:$file");

my $app = sub {
    my $env = shift;
    my $uri = RDF::Light::uri($env);

    my ($code, $msg) = (404,"URI $uri not found");

    if ( not $env->{'rdflight.type'} ) {
        my ($title, $body) = ('Not found',$msg);
        my %country;

        my $iterator = $model->get_statements( iri($uri), undef, undef );
        if ( $iterator->peek ) {
            ($title, $body) = ('Country','');
            while (my $stm = $iterator->next) {
                my $pred = $stm->predicate->uri_value;
                $pred =~ s!^http://downlode.org/rdf/iso-3166/schema\#!!;
                my $obj = escapeHTML($stm->object->as_string);
                $body .= "<dt>".$pred."</dt>";
                $body .= "<dd>".$obj."</dd>";
            }
            $body .= "</dl>";
            my $uri = Plack::Request->new($env)->uri;
            $uri =~ s/\?.*$//;
            my @links = map { "<a href='$uri?format=$_'>$_</a>" } qw(ttl xml json);
            $body .= "<p>".join(' / ',@links)."</p>";
        }
        $title = escapeHTML($title);
        $msg = <<HTML;
<html><head><title>$title</title></head>
<body><h1>$title</h1>$body</body></html>
HTML
    }

    utf8::downgrade($msg);

    return [ $code, ['Content-Type'=>'text/html'], [ $msg ] ];
};

use RDF::Trine qw(iri);
use RDF::Trine::Iterator;

builder {
    enable "+RDF::Light", source => $model, base => $base;
    $app;
};

