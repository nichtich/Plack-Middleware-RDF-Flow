use strict;
use warnings;
package RDF::Light::Source::Cascade;
# ABSTRACT: Returns the first non-empty response of a sequence of sources

use Log::Contextual::WarnLogger;
use Log::Contextual qw(:log), -default_logger 
    => Log::Contextual::WarnLogger->new({ env_prefix => __PACKAGE__ });

use parent 'RDF::Light::Source';
our @EXPORT = qw(cascade);

use Scalar::Util 'blessed';
use Carp 'croak';

sub new {
    my $class = shift;
	bless [ map { RDF::Light::Source::source($_) } @_ ], $class;
}

sub retrieve { # TODO: try/catch errors?
    my ($self, $env) = @_;

    log_trace { __PACKAGE__ . '::retrieve with ' . scalar @$self . ' sources' };

    foreach my $src ( @$self ) {
        my $rdf = $src->retrieve( $env );

		next unless defined $rdf;
		if ( blessed $rdf and $rdf->isa('RDF::Trine::Model') ) {
	        return $rdf if $rdf->size > 0;
		} elsif ( blessed $rdf and $rdf->isa('RDF::Trine::Iterator') ) {
	        return $rdf if $rdf->peek;
	    } else {
		    croak 'unexpected response in source union: '.$rdf;
		}
    }

    return;
}

sub cascade { RDF::Light::Source::Cascade->new(@_) }

1;

__END__

=head1 DESCRIPTION

This L<RDF::Light::Source> returns the first non-empty response of a given
sequence of sources. It exports the function 'cascade' as constructor shortcut.

=head1 SYNOPSIS

	use RDF::Light::Source::Cascade;

	$src = cascade(@sources);                            # shortcut
    $src = RDF::Light::Source::Cascade->new( @sources ); # explicit
	$rdf = $src->retrieve( $env );

=head2 SEE ALSO

L<RDF::Light::Source::Union>, L<RDF::Light::Source::Pipeline>

=cut
