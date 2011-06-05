package RDF::Light::Graph;

use strict;
use warnings;

=head1 NAME

RDF::Light::Graph - Lightweight access to RDF data

=head1 DESCRIPTION

This package provides some classes that wrap L<RDF::Trine::Node> and its
subclasses for easy use of RDF data, especially within L<Template> Toolkit.

An instance of RDF::Light::Graph wraps access to a set of RDF triples by
using qualified names with namespace prefixes instead of full URIs.

=cut

use RDF::Trine::Model;
use RDF::Trine::NamespaceMap;

sub new {
    my ($class, %arg) = @_;
    my $namespaces = $arg{namespaces} || RDF::Trine::NamespaceMap->new;
    my $model      = $arg{model}      || RDF::Trine::Model->new;

    bless {
        namespaces => $namespaces,
        model      => $model
    }, $class;
}

sub objects {
    my ($self, $subject, $property) = @_;

    # TODO: subject to Trine object unless given as such

    if ($property =~ /^([^_]*)_(.+)(_?)$/) {
        my $p = $self->{namespaces}->uri("$1:$2") or return;
        my $all = $3;

        my @objects = $self->{model}->objects( $subject, $p );
        return unless @objects;
        
        if ($all) {
           return [ map { $self->node( $_ ) } @objects ];
        } else {   
           return $self->node( $objects[0] );
        }
    }

    return;
}

sub node {
    my $self = shift;

    return $self->resource( @_ )
        if UNIVERSAL::isa( $_[0], 'RDF::Trine::Node::Resource' );

    return $self->literal( @_ )
        if UNIVERSAL::isa( $_[0], 'RDF::Trine::Node::Literal' );

    return $self->blank( @_ )
        if UNIVERSAL::isa( $_[0], 'RDF::Trine::Node::Blank' );

    return;
}

sub resource { RDF::Light::Node::Resource->new( @_ ) }
sub literal  { RDF::Light::Node::Literal->new( @_ ) }
sub blank    { RDF::Light::Node::Blank->new( @_ ) }


package RDF::Light::Node::Literal; # wraps a RDF::Trine::Node::Literal

use CGI qw(escapeHTML);

use overload '""' => sub { shift->str; };

sub new {
    my $class  = shift;
    my $graph  = shift || RDF::Light::Node::Graph->new;

    my ($literal, $language, $datatype) = @_;
    
    if (!UNIVERSAL::isa( $literal, 'RDF::Trine::Node::Literal')) {
        $literal = RDF::Trine::Node::Literal->new( $literal, $language, $datatype );
        # TODO: could be undef
    }

    return bless {
        literal => $literal,
        graph   => $graph,
    }, $class;
}

sub str { shift->{literal}->literal_value }

sub esc { escapeHTML( shift->{literal}->literal_value ) }

sub lang { shift->{literal}->literal_value_language } # TODO: 'language' object?

sub type { 
    my $self = shift;
    $self->{graph}->resource( $self->{literal}->literal_datatype );
}

# we may use a HTML method for xml:lang="lang">$str</

package RDF::Light::Node::Blank;

sub new {
    my $class = shift;
    my $graph = shift || RDF::Light::Node::Graph->new;
    my $id    = shift; 

    $id = $id->blank_identifier 
        if UNIVERSAL::isa($id,'RDF::Trine::Node::Blank');

    # TODO: $id could be undef or malformed

    return bless { 
        id    => $id,
        graph => $graph,
    }, $class;
}

sub id { shift->{id}; }


package RDF::Light::Node::Resource;

use CGI qw(escapeHTML);

our $AUTOLOAD;

use overload '""' => sub { shift->uri; };

sub new {
    my $class    = shift;
    my $graph    = shift || RDF::Light::Node::Graph->new;
    my $resource = shift; 

    return unless defined $resource;

    if (!UNIVERSAL::isa( $resource, 'RDF::Trine::Node::Resource')) {
        $resource = RDF::Trine::Node::Resource->new( $resource );
        # TODO: could be undef
    }

    return bless { 
        resource => $resource, 
        graph    => $graph,
    }, $class;
}

sub uri { 
    return shift->{resource}->value 
}

sub href { 
    return escapeHTML(shift->{resource}->value); 
}

*esc = *href;

sub AUTOLOAD {
    my $self = shift;
    return if !ref($self) or $AUTOLOAD =~ /^(.+::)?DESTROY$/;

    my $property = $AUTOLOAD;
    $property =~ s/.*:://;

    return $self->{graph}->objects( $self->{resource}, $property );
}

1;
