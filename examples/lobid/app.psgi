use strict;
use warnings;

use Plack::Builder;
use Plack::Middleware::TemplateToolkit; # requires '0.12' from github

use RDF::Light;
use RDF::Light::Graph;

use Log::Contextual::WarnLogger;
use Log::Contextual qw(:log :dlog), -default_logger 
    => Log::Contextual::WarnLogger->new({ env_prefix => 'LOBID_PROXY' });

use RDF::Trine::NamespaceMap;
use RDF::Trine::Parser;

use URI::Escape;

use constant ENVIRONMENT         => 'development';
use constant ENABLE_DEBUG_PANELS => (ENVIRONMENT eq 'development');

use Try::Tiny;

use File::Basename; use Cwd;
my $dir  = Cwd::realpath( dirname($0) );
sub catfile { use File::Spec; File::Spec->catfile( $dir, @_ ); }

my $namespaces = RDF::Trine::NamespaceMap->new({
   rdfs    => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
   country => 'http://downlode.org/rdf/iso-3166/countries#',
   dcterms => 'http://purl.org/dc/terms/',
   foaf    => 'http://xmlns.com/foaf/0.1/',
   geo     => 'http://www.w3.org/2003/01/geo/wgs84_pos#',
   hcterms => 'http://purl.org/uF/hCard/terms/',
   rdf     => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
   vcard   => 'http://www.w3.org/2006/vcard/ns#',
   xsd     => 'http://www.w3.org/2001/XMLSchema#',
});

sub lobid_source {
    my $env = shift;
    my $uri = RDF::Light::uri( $env ) || '';

    my $model = RDF::Trine::Model->new;
    if ( $uri =~ qr{^http://lobid.org/organisation/(.+)} ) {
        my $url = "http://lobid.org/organisation/data/$1.rdf";

        try {
            RDF::Trine::Parser->parse_url_into_model( $url, $model );
            log_debug { "retrieved data from $url" };
        } catch {
            die "Failed to retrieve data from $url";
        };
    }
    return $model;
};

my $base = 'http://lobid.org/organisation/';
my $tt_app  = Plack::Middleware::TemplateToolkit->new( 
    INCLUDE_PATH => catfile(), INTERPOLATE => 1, pass_through => 0,
    404 => '404.html', 
    500 => '500.html', 502 => '502.html', 501 => '502.html', 504 => '504.html',
    ENCODING => 'utf8', #utf8_downgrade => 1 # because of bad UTF8 in source?
);

my $rdflight = RDF::Light->new( base => $base, source => \&lobid_source );

builder {
    enable_if { ENABLE_DEBUG_PANELS } 'StackTrace';
    enable_if { ENABLE_DEBUG_PANELS } 'Debug';
    enable_if { ENABLE_DEBUG_PANELS } 'Lint';
    enable_if { ENABLE_DEBUG_PANELS } 'Runtime';
    enable_if { ENABLE_DEBUG_PANELS } 'ConsoleLogger';
#     enable 'SimpleLogger';
    enable 'Log::Contextual', level => 'trace';

    enable 'Static', root => catfile(), path => qr{\.css$};

    enable 'JSONP';
    enable_if { $_[0]->{PATH_INFO} =~ /^\/DE-/ } # $rdflight 
        sub { $rdflight->app(shift); $rdflight->to_app; };

    enable sub { # in lack of Plack::Middleware::Redirect
        my $app = shift;
        sub {
            my $env = shift;
            my $req = Plack::Request->new( $env );
            my $isil = $req->query_parameters->{isil};
            if ( $isil ) {
                my $redir = $req->base . uri_escape($isil);
                [ 302, [ Location => $redir ], 
                       [ "<html><body><a href=\"$redir\">redirect</a></body></html>"] ];
            } else {
                $app->($env);
            }
        }
    };

    enable sub { 
        my $app = shift;
        sub {
            my $env = shift;
            my $req = Plack::Request->new( $env );
            if ( $env->{'rdflight.uri'} ) {
                my $page = '/404';
                my $vars = { formats => [qw(json ttl rdf)], base => $req->base };

                my $model = $rdflight->retrieve( $env );
                if ($env->{'rdflight.error'}) {
                    log_error { $env->{'rdflight.error'} };
                    $vars->{'error'} = $env->{'rdflight.error'};
                    if (not $model) {
                        $tt_app->prepare_app;
                        return $tt_app->process_error(404, $vars->{'error'} );
                    }
                }

                # TODO: 404 and 500
#                $env->{PATH_INFO} = 'organization.html'; # this will fail

                if ( $model ) {
                    $page = '/organization.html'; # TODO: other pages

                    my $graph = RDF::Light::Graph->new( namespaces => $namespaces, model => $model );

                    my $uri = $env->{'rdflight.uri'};
                    if ( $uri ) { 
                        $vars->{uri} = $graph->resource($uri); 
                    }
                } # else ?

                $env->{PATH_INFO} = $page;
                $env->{'tt.vars'} = $vars;
                log_trace { 'tt.vars prepared' };
            } else {
                log_trace { 'no URI detected' };
                $env->{PATH_INFO} = '';
            }

            $app->( $env );
        }
    };
 
    $tt_app;
};

