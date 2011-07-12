use strict;

my @modules;

BEGIN { @modules = qw(
RDF::Light
RDF::Light::Source
RDF::Light::Source::Union 
RDF::Light::Source::Cascade
); }

use Test::More tests => scalar @modules;

use_ok($_) for @modules;
