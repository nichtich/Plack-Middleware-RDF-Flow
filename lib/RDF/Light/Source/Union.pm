use strict;
use warnings;
package RDF::Light::Source::Union;

use parent 'RDF::Light::Source';

our @EXPORT = qw(union);

sub new {
    my $class = shift;
	bless [ map { RDF::Light::Source::source($_) } @_ ], $class;
}

sub retrieve { # TODO: try/catch errors?
    my ($self, $env) = @_;

    my $result;

    if ( @$self == 1 ) {
        $result = $self->[0]->retrieve( $env );
    } elsif( @$self > 1 ) {
        $result = RDF::Trine::Model->temporary_model;
        foreach my $src ( @$self ) { # TODO: parallel processing?
		    my $rdf = $src->retrieve( $env );
			next unless defined $rdf;
			$rdf = $rdf->as_stream unless $rdf->isa('RDF::Trine::Iterator');
            RDF::Light::Source::add_iterator( $result, $rdf );
        }
    }

    return $result;
}

sub union { RDF::Light::Source::Union->new(@_) }

1;

__END__

=head1 DESCRIPTION

This L<RDF::Light::Source> returns the union of responses of a set of sources.
It exports the function 'union' as constructor shortcut.

=head1 SYNOPSIS

	use RDF::Light::Source::Union;

	$src = union(@sources);                            # shortcut
    $src = RDF::Light::Source::Union->new( @sources ); # explicit
	$rdf = $src->retrieve( $env );

=head2 SEE ALSO

L<RDF::Light::Source::Cascade>, L<RDF::Light::Source::Pipeline>

=cut
