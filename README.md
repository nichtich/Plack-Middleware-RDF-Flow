# RDF::Light

This project provides a set of Perl modules to create simple RDF-based web 
applications. It is in a very premature state of development and will not 
be published as "official" Perl module on CPAN before further testing and
discussion. If you are interested in Perl and RDF in general, you should 
have a look at the [RDF and Perl page](http://www.perlrdf.org/).

The priority of RDF::Light is ease of use, but not 100% conformance with
every aspect of the RDF technology stack.

## Get started

Make sure you have [installed Perl](http://www.perl.org/get.html) and you have
a command line interface (the following statements after `$` are commands). I
recommend [cpanminus](http://search.cpan.org/perldoc?App::cpanminus#INSTALL)
to install required Perl modules. To use all of RDF::Light you need:

1. [RDF-Trine](http://search.cpan.org/dist/RDF-Trine/)
2. [Plack](http://plackperl.org/)
3. [Template Toolkit](http://template-toolkit.org/)

With cpanminus you should be able to install these with the following commands:

    $ cpanm RDF::Trine
    $ cpanm Task::Plack
    $ cpanm Template

Download RDF::Light [from github](https://github.com/nichtich/RDF-Light/) via
the web interface (the "Downloads" button at the right) or clone via git:

    $ git clone git://github.com/nichtich/RDF-Light.git
    $ cd RDF-Light

Once you have extracted all files in a directory you can run one of the example
applications:

    $ plackup -Ilib -r examples/countries/app.psgi
    $ plackup -Ilib -r examples/lobid/app.psgi

Browse to http://localhost:5000 and you should get an HTML page with a list
of country names as example. Have a look at the source code in the examples
directory, modify them and see the results, and read the documentation.

## Technical overview

RDF::Light consists of the following (sets of) classes, that can each be used
independently. Some of them may get renamed or merged to existing Perl modules:

* RDF::Light         - a PSGI Middleware for Linked Data
* RDF::Light::Source - a method to combine sources of RDF data

This list is not complete or stable. If you have suggestions or comments, you
are welcome to [submit an issue](https://github.com/nichtich/RDF-Light/issues)!

## Author

RDF::Light is created by Jakob Voß

## License

By now, licensed under the GNU Affero General Public License - that means if
you use RDF::Light for public applications and extend the core modules, you
*must* also publish your extensions. The final license may be less strict.

