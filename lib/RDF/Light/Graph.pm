package RDF::Light::Graph;

use strict;
use warnings;

=head1 NAME

RDF::Light::Graph - Lightweight access to RDF data

=head1 DESCRIPTION

This package provides some classes that wrap L<RDF::Trine::Node> and its
subclasses for easy use of RDF data, especially within L<Template> Toolkit.
Basically there is RDF::Light::Graph for RDF graphs and there are
RDF::Light::Literal, RDF::Light::Resource, and RDF::Light::Blank for RDF nodes,
which each belong to an RDF graph.  Internally each node is represented by a
L<RDF::Trine::Node> objects that is connected to a particular RDF::Light::Graph.

=cut

use RDF::Trine::Model;
use RDF::Trine::NamespaceMap;

our $AUTOLOAD;

sub new {
    my ($class, %arg) = @_;
    my $namespaces = $arg{namespaces} || RDF::Trine::NamespaceMap->new;
    my $model      = $arg{model}      || RDF::Trine::Model->new;

    bless {
        namespaces => $namespaces,
        model      => $model
    }, $class;
}

sub model { shift->{model} }

sub objects {
    my ($self, $subject, $property) = @_;

    $subject = $self->node($subject)
        unless UNIVERSAL::isa( $subject, 'RDF::Light::Node' );

    my $all = 1 if ($property =~ s/^(.+[^_])_$/$1/);
    my $predicate = $self->node($property);

    if (defined $predicate) {
        my @objects = $self->{model}->objects( $subject->trine, $predicate->trine );
        return unless @objects;
        
        if ($all) {
           return [ map { $self->node( $_ ) } @objects ];
        } else {   
           return $self->node( $objects[0] );
        }
    }

    return;
}

sub resource { RDF::Light::Node::Resource->new( @_ ) }
sub literal  { RDF::Light::Node::Literal->new( @_ ) }
sub blank    { RDF::Light::Node::Blank->new( @_ ) }

sub node {
    my $self = shift;

    if (!UNIVERSAL::isa( $_[0], 'RDF::Trine::Node' )) {
        my $name = shift;
        return unless defined $name and $name =~ /^(([^_]*)_)?([^_]+.*)$/;

        my $local = $3;
        $local =~ s/__/_/g;

        my $uri;

        if (defined $2) {
            $uri = $self->{namespaces}->uri("$2:$local");
        } else {
            # TODO: Fix bug in RDF::Trine::NamespaceMap, line 133
            # $predicate = $self->{namespaces}->uri(":$local");
            my $ns = $self->{namespaces}->namespace_uri("");
            $uri = $ns->uri($local) if defined $ns;
        }

        return unless defined $uri; 
        @_ = ($uri);
    }

    return $self->resource( @_ )
        if UNIVERSAL::isa( $_[0], 'RDF::Trine::Node::Resource' );

    return $self->literal( @_ )
        if UNIVERSAL::isa( $_[0], 'RDF::Trine::Node::Literal' );

    return $self->blank( @_ )
        if UNIVERSAL::isa( $_[0], 'RDF::Trine::Node::Blank' );

    return;
}

sub add {
    my ($self, $add) = @_;
    
    if (UNIVERSAL::isa($add, 'RDF::Trine::Statement')) {
        $self->model->add_statement( $add );
    } elsif (UNIVERSAL::isa($add, 'RDF::Trine::Iterator')) {
        # No RDF::Trine::Model::add_iterator ?
        while (my $st = $add->next) {
            $self->add( $st );
        }
    }
}

sub AUTOLOAD {
    my $self = shift;
    return if !ref($self) or $AUTOLOAD =~ /^(.+::)?DESTROY$/;

    my $name = $AUTOLOAD;
    $name =~ s/.*:://;

    return if $name =~ /^(uri|query|sparql|model)$/; # reserved words

    return $self->node($name);
}


package RDF::Light::Node;

sub trine { shift->[0]; }
sub graph { shift->[1]; }
sub esc   { shift->str; }

package RDF::Light::Node::Literal;
use base 'RDF::Light::Node';
use CGI qw(escapeHTML);

use overload '""' => sub { shift->str; };

sub new {
    my $class  = shift;
    my $graph  = shift || RDF::Light::Node::Graph->new;

    my ($literal, $language, $datatype) = @_;
    
    $literal = RDF::Trine::Node::Literal->new( $literal, $language, $datatype )
        unless UNIVERSAL::isa( $literal, 'RDF::Trine::Node::Literal');
    return unless defined $literal;
    
    return bless [ $literal, $graph ], $class;
}

sub str { shift->trine->literal_value }

sub esc { escapeHTML( shift->trine->literal_value ) }

sub lang { shift->trine->literal_value_language } # TODO: 'language' object?

sub type { 
    my $self = shift;
    $self->graph->resource( $self->trine->literal_datatype );
}

# we may use a HTML method for xml:lang="lang">$str</


package RDF::Light::Node::Blank;
use base 'RDF::Light::Node';

sub new {
    my $class = shift;
    my $graph = shift || RDF::Light::Node::Graph->new;
    my $blank = shift; 

    $blank = RDF::Trine::Node::Blank->new( $blank )
        unless UNIVERSAL::isa( $blank, 'RDF::Trine::Node::Blank' );
    return unless defined $blank;

    return bless [ $blank, $graph ], $class;
}

sub id { 
    shift->trine->blank_identifier
}

*str = *id;

# TODO: check whether non-XML characters are possible for esc

package RDF::Light::Node::Resource;
use base 'RDF::Light::Node';
use CGI qw(escapeHTML);

use overload '""' => sub { shift->str; };

our $AUTOLOAD;

sub new {
    my $class    = shift;
    my $graph    = shift || RDF::Light::Node::Graph->new;
    my $resource = shift; 

    return unless defined $resource;

    if (!UNIVERSAL::isa( $resource, 'RDF::Trine::Node::Resource')) {
        $resource = RDF::Trine::Node::Resource->new( $resource );
        return unless defined $resource;
    }

    return bless [ $resource, $graph ], $class;
}

sub uri { 
    shift->trine->value 
}

sub href { # TODO: check whether non-XML characters are possible
    escapeHTML(shift->trine->value); 
}

sub objects { # TODO: rename to 'attr' or 'prop' ?
    $_[0]->graph->objects( @_ ); 
}

*esc = *href;
*str = *uri;

sub AUTOLOAD {
    my $self = shift;
    return if !ref($self) or $AUTOLOAD =~ /^(.+::)?DESTROY$/;

    my $property = $AUTOLOAD;
    $property =~ s/.*:://;

    return if $property =~ /^(query|lang)$/; # reserved words

    return $self->objects( $property );
}

1;

=head1 NODE METHODS

In general you should not use the node constructor to create new node objects
but use a graph as node factory:

    $graph->resource( $uri );
    $graph->literal( $string, $language, $datatype );
    $graph->blank( $id );

However, the following syntax is equivalent:

    RDF::Light::Node::Resource->new( $graph, $uri );
    RDF::Light::Node::Literal->new( $graph, $string, $language, $datatype );
    RDF::Light::Node::Blank->new( $graph, $id );

To convert a RDF::Trine::Node object into a RDF::Light::Node, you can use:

    $graph->node( $trine_node )

Note that all these methods silently return undef on failure.

Each RDF::Light::Node provides at least three access methods:

=over 4

=item str

Returns a string representation of the node's value. Is automatically
called on string conversion (C<< "$x" >> equals C<< $x->str >>).

=item esc

Returns a HTML-escaped string representation. This can safely be used
in HTML and XML.

=item trine

Returns the underlying L<RDF::Trine::Node>.

=item graph

Returns the underlying graph L<RDF::Light::Graph> that the node belongs to.

=back

In addition for literal nodes:

=over 4

=item esc

...

=item lang

...

=item type

...

=back

In addition for blank nodes:

=over 4

=item id

Returns the local, temporary identifier of this note.

=back

In addition for resource nodes:

=over 4

=item uri

...

=item href

...

=item objects

Any other method name is used to query objects. The following three statements
are equivalent:

   $x->foaf_name;
   $x->objects('foaf_name');
   $x->graph->objects( $x, 'foaf_name' );

=back


=head1 GRAPH METHODS

An instance of RDF::Light::Graph wraps access to a set of RDF triples by
using qualified names with namespace prefixes instead of full URIs.

=over 4

=item resource
=item literal
=item blank

Returns a node of the given type, as described above.

=item node ( $name | $node )

Returns a node that is connected to the graph. Note that every valid RDF node
is part of any RDF graph: this method does not check whether the graph actually
contains a triple with the given node. You can either pass a name or an
instance of L<RDF::Trine::Node>. This method is also called for any undefined
method, so the following statements are equivalent:

    $graph->alice;
    $graph->node('alice');

=item objects ( $subject, $property )

Returns a list of objects that occur in statements in this graph. The full
functionality of this method is not fixed yet.

=back

=cut

