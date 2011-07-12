use strict;
use warnings;
package RDF::Light::Source::Pipeline;

use parent 'RDF::Light::Source';

our @EXPORT = qw(pipeline previous);

sub new {
    my $class = shift;
	bless [ map { RDF::Light::Source::source($_) } @_ ], $class;
}

sub retrieve {
    my ($self, $env) = @_;

    foreach my $src ( @$self ) {
        my $rdf = $src->retrieve( $env );
        $env->{'rdflight.data'} = $rdf;
		return $rdf unless RDF::Light::Source::has_content( $rdf );
    }

    $env->{'rdflight.data'};
}

sub pipeline { RDF::Light::Source::Pipeline->new(@_) }

sub previous { $RDF::Light::Source::PREVIOUS; }

1;

__END__

=head1 DESCRIPTION

This L<RDF::Light::Source> wraps other sources as pipeline. Sources are 
retrieved one after another. The response of each source is saved in the
environment variable 'rdflight.data' which is accesible to the next source.
The pipeline is aborted without error if rdflight.data has not content
(see RDF::Light::Source::has_content), so you can also use a pipleline as 
conditional branch. To pipe one source after another, you can also use the 
'pipe_to' method of RDF::Light::Source.

=head1 SYNOPSIS

	use RDF::Light::Source::Pipeline;

	$src = pipeline( @sources );                           # shortcut
    $src = RDF::Light::Source::Pipeline->new( @sources );  # explicit
	$rdf = $src->retrieve( $env );
    $rdf == $env->{'rdflight.data'};                       # always true

    # pipeline as conditional: if $s1 has content then union of $1 and $2
    use RDF::Light::Source::Union;
    pipeline( $s1, union( previous, $s2 ) );
    $s1->pipe_to( union( previous, $s2) );    # equivalent 

=head1 EXPORTED FUNCTIONS

=over 4

=item pipeline

Constructor shortcut.

=item previous

Returns a source that always returns rdflight.data without modification.

=head2 SEE ALSO

L<RDF::Light::Source::Cascade>, L<RDF::Light::Source::Union>

=cut
