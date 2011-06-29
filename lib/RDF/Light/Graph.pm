use strict;
use warnings;
package RDF::Light::Graph;

=head1 NAME

RDF::Light::Graph - Lightweight access to RDF data

=head1 DESCRIPTION

This package provides classes for a node-centric API to access RDF data. The
classes wrap L<RDF::Trine::Node> and its subclasses for easy use of RDF data,
especially within L<Template> Toolkit.  Basically there is RDF::Light::Graph
for RDF graphs and there are RDF::Light::Literal, RDF::Light::Resource, and
RDF::Light::Blank for RDF nodes, which each belong to an RDF graph.  Internally
each node is represented by a L<RDF::Trine::Node> objects that is connected to
a particular RDF::Light::Graph.

=cut

use RDF::Trine::Model;
use RDF::Trine::NamespaceMap;
use CGI qw(escapeHTML);

our $AUTOLOAD;

sub new {
    my ($class, %arg) = @_;
    my $namespaces    = $arg{namespaces} || RDF::Trine::NamespaceMap->new;
    my $model         = $arg{model}      || RDF::Trine::Model->new;

    bless {
        namespaces => $namespaces,
        model      => $model
    }, $class;
}

sub model { $_[0]->{model} }

sub objects { # TODO: rename to 'attr' or 'prop' ?
    my $self     = shift;
    my $subject  = shift;
    my $property = shift; # mandatory
    my @filter   = @_;

    $subject = $self->node($subject)
        unless UNIVERSAL::isa( $subject, 'RDF::Light::Node' );

    # TODO: support ns:local syntax in addition to ns_local
    my $all = ($property =~ s/^(.+[^_])_$/$1/) ? 1 : 0;
    my $predicate = $self->node($property);

    if (defined $predicate) {
        my @objects = $self->{model}->objects( $subject->trine, $predicate->trine );

        @objects = map { $self->node( $_ ) } @objects;

        # TODO apply filters one by one and return in order of filters
        @objects = grep { $_->is(@filter) } @objects
            if @filter;

        return unless @objects;
        
        if ($all) {
           return \@objects;
        } else {   
           return $objects[0];
        }
    }

    return;
}

sub turtle { # FIXME
    my $self     = shift;
    my $subject  = shift;

    $subject = $self->node($subject)
        unless UNIVERSAL::isa( $subject, 'RDF::Light::Node' );
   
    use RDF::Trine::Serializer::Turtle;
    my $serializer = RDF::Trine::Serializer::Turtle->new( namespaces => $self->{namespaces} );

    my $iterator = $self->{model}->bounded_description( $subject->trine );
    my $turtle   = $serializer->serialize_iterator_to_string( $iterator );
    my $html     = escapeHTML( '# '.$subject->str."\n$turtle" );

    return '<pre class="turtle">'.$html.'</pre>';
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
        _add_iterator( $self->model, $add ); 
    } elsif (UNIVERSAL::isa($add, 'RDF::Trine::Model')) {
        $self->add( $add->as_stream ); # TODO: test this
    }

    # TODO: add triple with subject, predicate in custom form and object
    # as custom form, blank, or literal
}

# Is there no RDF::Trine::Model::add_iterator ??
sub _add_iterator {
    my ($model, $iter) = @_;
    
    $model->begin_bulk_ops;
    while (my $st = $iter->next) { 
        $model->add_statement( $st ); 
    }
    $model->end_bulk_ops;
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

our $AUTOLOAD;

sub trine { shift->[0]; }
sub graph { shift->[1]; }
sub esc   { shift->str; }

sub is_literal  { shift->[0]->is_literal; }
sub is_resource { shift->[0]->is_resource; }
sub is_blank    { shift->[0]->is_blank; }

sub AUTOLOAD {
    my $self = shift;
    return if !ref($self) or $AUTOLOAD =~ /^(.+::)?DESTROY$/;

    my $method = $AUTOLOAD;
    $method =~ s/.*:://;

    return $self->_autoload( $method, @_ );
}

sub is {
    my $self = shift;
    return 1 unless @_;

    foreach my $check (@_) {
        if ($self->is_literal) {
            return 1 if $check eq '' or $check eq 'literal';
            return 1 if $check eq '@' and $self->lang;
            return 1 if $check =~ /^@(.+)/ and $self->lang($1);
            return 1 if $check eq /^\^\^?$/ and $self->datatype;
        } elsif ($self->is_resource) {
            return 1 if $check eq ':' or $check eq 'resource';
        } elsif ($self->is_blank) {
            return 1 if $check eq '-' or $check eq 'blank';
        }
    }

    return 0;
}

sub turtle {
    return $_[0]->graph->turtle( @_ );
}

sub objects { # TODO: rename to 'attr' or 'prop' ?
    $_[0]->graph->objects( @_ ); 
}

sub _autoload {
    my $self     = shift;
    my $property = shift;
    return if $property =~ /^(query|lang)$/; # reserved words
    return $self->objects( $property, @_ );
}


package RDF::Light::Node::Literal;
use base 'RDF::Light::Node';
use CGI qw(escapeHTML);

use overload '""' => sub { shift->str; };

# not very strict check for language tag look-alikes (see www.langtag.net)
our $LANGTAG = qr/^(([a-z]{2,8}|[a-z]{2,3}-[a-z]{3})(-[a-z0-9_]+)?-?)$/;

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

sub lang { 
    my $self = shift;
    my $lang = $self->trine->literal_value_language;
    return $lang if not @_ or not $lang;

    my $xxx = shift || "";
    $xxx =~ s/_/-/g;
    return unless $xxx =~ $LANGTAG;

    if ( $xxx eq $lang or $xxx =~ s/-$// and index($lang, $xxx) == 0 ) {
        return $lang;
    }

    return; 
}

sub type { 
    my $self = shift;
    $self->graph->resource( $self->trine->literal_datatype );
}

# we may use a HTML method for xml:lang="lang">$str</

sub _autoload {
    my $self   = shift;
    my $method = shift;

    return unless $method =~ /^is_(.+)$/;

    # We assume that no language is named 'blank', 'literal', or 'resource'
    return 1 if $self->lang($1);
        
    return;
}

sub objects { } # literal notes have no properties


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

sub str { # TODO: check whether non-XML characters are possible for esc
    '_:'.shift->trine->blank_identifier
}


package RDF::Light::Node::Resource;
use base 'RDF::Light::Node';
use CGI qw(escapeHTML);

use overload '""' => sub { shift->str; };

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
    shift->trine->uri_value 
}

sub href { # TODO: check whether non-XML characters are possible
    escapeHTML(shift->trine->uri_value); 
}

*esc = *href;
*str = *uri;

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

Each RDF::Light::Node provides at least the following methods:

=over 4

=item str

Returns a string representation of the node's value. Is automatically
called on string conversion (C<< "$x" >> equals C<< $x->str >>).

=item esc

Returns a HTML-escaped string representation. This can safely be used
in HTML and XML.

=item is_literal / is_resource / is_blank

Returns true if the node is a literal / resource / blank node.

=item is ( $check1 [, $check2 ... ] ) 

Checks whether the node fullfills some matching criteria. 

=item trine

Returns the underlying L<RDF::Trine::Node>.

=item graph

Returns the underlying graph L<RDF::Light::Graph> that the node belongs to.

=item turtle

Returns an HTML escaped RDF/Turtle representation of the node's bounded 
connections.

=item dump

Returns an HTML representation of the node and its connections
(not implemented yet).

=back

In addition for literal nodes:

=over 4

=item esc

...

=item lang

Return the literal's language tag (if the literal has one).

=item type

...

=item is_xxx

Returns whether the literal has language tag xxx, where xxx is a BCP 47 language
tag locator. For instance C<is_en> matches language tag C<en> (but not C<en-us>), 
C<is_en_us> matches language tag C<en-us> and C<is_en_> matches C<en> and all
language tags that start with C<en->. Use C<lang> to check whether there is any
language tag.

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

You can also add filters in a XPath-like language (the use of RDF::Light::Graph 
in a template is an example of a "RDFPath" language):
  
    $x->dc_title('@en')   # literal with language tag @en
    $x->dc_title('@en-')  # literal with language tag @en or @en-...
    $x->dc_title('')      # any literal
    $x->dc_title('@')     # literal with any language tag
    $x->dc_title('^')     # literal with any datatype
    $x->foaf_knows(':')   # any resource
    ...

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

=item turtle ( [ $node ] )

Returns an HTML escaped RDF/Turtle representation of a node's bounded 
connections (not fully implemented yet).

=item dump ( [ $node ] )

Returns an HTML representation of a selected node and its connections or of
the full graph (not implemented yet).

=back

=cut
