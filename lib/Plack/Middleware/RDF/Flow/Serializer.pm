use strict;
use warnings;
package Plack::Middleware::RDF::Flow::Serializer;
#ABSTRACT: Lightweight RDF serializer base class

use Plack::Util::Accessor qw(mime);
use Carp;

our $mime_type;

# copied from Plack::Component
sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self;
    if (@_ == 1 && ref $_[0] eq 'HASH') {
        $self = bless {%{$_[0]}}, $class;
    } else {
        $self = bless {@_}, $class;
    }

    { 
        no strict 'refs';
        $self->mime( ${ ref($self) . '::mime_type' } ) unless $self->mime;
    }
    croak 'serializer requires a mime type' unless $self->mime;

    $self;
}

sub media_types {
    my $self = shift;
    return ($self->mime);
}

sub serialize_model_to_string {
    my ($self, $model) = @_;

    carp 'you must implement ' . ref($self) . '::serialize_model_to_string';

    return '';
}

sub serialize_iterator_to_string {
    my ($self, $iter) = @_;
    my $model = RDF::Trine::Model->temporary_model;
    $model->begin_bulk_ops;
    while (my $st = $iter->next) {
        $model->add_statement( $st );
    }
    $model->end_bulk_ops;
    return $self->serialize_model_to_string( $model );
}

1;

=head1 SYNOPIS

  package Your::Serializer;
  use parent 'Plack::Middleware::RDF::Flow::Serializer';

  use Plack::Util::Accessor qw(foo bar);  # config options of your serializer
  our $mime_type = "foo/bar";             # mime type of your serializer 

  sub serialize_model_to_string {
      my ($self, $model) = @_;

      # create serialization
      
      return $strimg;
  }

=head1 DESCRIPTION

This class can be used to define custom RDF serialization formats. You can also
use use L<RDF::Trine::Serializer>, but if you want to decouple serializer
definition from content negotiation and if your serialization format has just
one MIME type, this module may be an alternative.

=method new ( { key => $value } )

Creates a new serializer.

=method media_types

Returns the mime type as one-element list.

=method serialize_model_to_string ( $model )

Serializes a L<RDF::Trine::Model>. You must implement this method in your
subclass.

=method serialize_iterator_to_string ( $iterator )

Serialize a L<RDF::Trine::Iterator::Graph>. You may implement this method
in your class. By default it used C<serialize_model_to_string>.

=cut

