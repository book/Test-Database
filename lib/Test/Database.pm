package Test::Database;
use warnings;
use strict;

use File::HomeDir;
use File::Spec;
use DBI;
use Carp;

use Test::Database::Handle;

our $VERSION = '1.00';

# internal data structure
my @HANDLES;

# startup configuration
__PACKAGE__->load_config() if -e _rcfile();

#
# private functions
#
# location of our resource file
sub _rcfile {
    File::Spec->catfile( File::HomeDir->my_data(), '.test-database' );
}

# return a list of hashrefs representing each configuration section
sub _read_file {
    my ($file) = @_;
    my @config;

    open my $fh, '<', $file or croak "Can't open $file for reading: $!";
    my %args;
    while (<$fh>) {
        next if /^\s*(?:#|$)/;    # skip blank lines and comments
        chomp;

        /\s*(\w+)\s*=\s*(.*)\s*/ && do {
            my ( $key, $value ) = ( $1, $2 );
            if ( $key eq 'dsn' ) {
                push @config, {%args} if keys %args;
                %args = ();
            }
            $args{$key} = $value;
            next;
        };

        # unknown line
        croak "Can't parse line at $file, line $.:\n  <$_>";
    }
    push @config, {%args} if keys %args;
    close $fh;

    return @config;
}

#
# methods
#
sub clean_config {
    @HANDLES = ();
}

sub load_config {
    my ( $class, @files ) = @_;
    @files = ( _rcfile() ) if !@files;

    push @HANDLES,
        map { Test::Database::Handle->new(%$_) }
        map { _read_file($_) } @files;
}

# requests for handles
sub handles {
    my ( $class, @requests ) = @_;

    # empty request means "everything"
    return @HANDLES if !@requests;

    # turn strings (driver name) into actual requests
    @requests = map { (ref) ? $_ : { dbd => $_ } } @requests;

    # process parameter aliases
    $_->{dbd} ||= delete $_->{driver} for @requests;

    # get the matching handles
    my @handles;
    for my $handle (@HANDLES) {
        push @handles, $handle
            if grep { $_->{dbd} eq $handle->{dbd} } @requests;
    }

    # then on the handles
    return @handles;
}

sub handle {
    my @h = shift->handles(@_);
    return @h ? $h[0] : ();
}

'TRUE';

__END__

=head1 NAME

Test::Database - Database handles ready for testing

=head1 SYNOPSIS

Maybe you wrote generic code you want to test on all available databases:

    use Test::More;
    use Test::Database;

    # get all available handles
    my @handles = Test::Database->handles();

    # plan the tests
    plan tests => 3 + 4 * @handles;

    # run the tests
    for my $handle (@handles) {
        diag "Testing with " . $handle->dbd();    # mysql, SQLite, etc.

        # there are several ways to access the dbh:

        # let $handle do the connect()
        my $dbh = $handle->dbh();

        # do the connect() yourself
        my $dbh = DBI->connect( $handle->connection_info() );
        my $dbh = DBI->connect( $handle->dsn(), $handle->username(),
            $handle->password() );
    }

It's possible to limit the results, based on the databases your code
supports:

    my @handles = Test::Database->handles(
        'SQLite',                 # SQLite database
        { dbd    => 'mysql' },    # or mysql database
        { driver => 'Pg' },       # or Postgres database
    );

    # use them as above

If you only need a single database handle, all the following return
the same one:

    my $handle   = ( Test::Database->handles(@requests) )[0];
    my ($handle) = Test::Database->handles(@requests);
    my $handle   = Test::Database->handles(@requests);    # scalar context
    my $handle   = Test::Database->handle(@requests);     # singular!
    my @handles  = Test::Database->handle(@requests);     # one or zero item

You can use the same requests again if you need to use the same
test databases over several test scripts.

The C<cleanup()> method will drop all tables from C<supported> databases.

=head1 DESCRIPTION

Quoting Michael Schwern:

I<There's plenty of modules which need a database, and they all have
to be configured differently and they're always a PITA when you first
install and each and every time they upgrade.>

I<User setup can be dealt with by making Test::Database a build
dependency. As part of Test::Database's install process it walks the
user through the configuration process. Once it's done, it writes out
a config file and then it's done for good.>

See L<http://www.nntp.perl.org/group/perl.qa/2008/10/msg11645.html>
for the thread that led to the creation of C<Test::Database>.

C<Test::Database> provides a simple way for test authors to request
a test database, without worrying about environment variables or the
test host configuration.

See L<SYNOPSIS> for typical usage.

=head1 METHODS

C<Test::Database> provides the following methods:

=over 4

=item load_config( @files )

Read configuration from the files in C<@files>.

If no file is provided, the local equivalent of F<~/.test-database> is used.

=item clean_config()

Empties whatever configuration has already been loaded.

=item handles( @requests )

Return a set of C<Test::Database::Handle> objects that match the
given C<@requests>.

If C<@requests> is not provided, return all the available handles.

See L<REQUESTS> for details about writing requests.

=item handle( @request )

I<Singular> version of C<handles()>, that returns the first matching
handle.

=back

=head1 REQUESTS

The C<handles()> method takes I<requests> as parameters. A request is
a simple hash reference, with a number of recognized keys.

=over 4

=item *

C<dbd>: driver name (based on the C<DBD::> name).

C<driver> is an alias for C<dbd>.
If the two keys are present, the C<driver> key will be ignored.

=back

A request can also consist of a single string, in which case it is
interpreted as a shortcut for C<{ dbd => $string }>.

=head1 FILES

The list of available, authorized DSN is stored in the local equivalent
of F<~/.test-database>. It's a simple list of key/value pairs, with the
C<dsn> key being used to split successive entries:

    # mysql
    dsn      = dbi:mysql:database=mydb;host=localhost;port=1234
    username = user
    password = s3k r3t
    
    # DBD::CSV
    dsn      = dbi:CSV:f_dir=test-db
    
    # sqlite
    dsn      = dbi:SQLite:db.sqlite

The C<username> and C<password> keys are optional and empty strings will be
used if they are not provided.

Empty lines and comments are ignored.

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-test-database at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Database>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Database

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Test-Database>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Test-Database>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Test-Database>

=item * Search CPAN

L<http://search.cpan.org/dist/Test-Database>

=back

=head1 TODO

Some of the items on the TODO list:

=over 4

=item *

Bring back the C<Test::Database::Driver> modules from the limbo
they were put after version 0.99_04. First, for file-based drivers,
eventually for other database engines.

=item *

Simple support for always getting the same database between test scriptS.

=item *

Ensure each test suite gets a different database, if possible.
(It's impossible with fixed DSN gotten from the configuration file,
but rather trivial with file-based drivers.)

=item *

Write a Cookbook/Tutorial to make adoption easier for testers and module
authors.

=item *

Add a database engine autodetection script/module, to automatically
write the F<.test-database> configuration file.

=back

=head1 ACKNOWLEDGEMENTS

Thanks to C<< <perl-qa@perl.org> >> for early comments.

Thanks to Nelson Ferraz for writing C<DBIx::Slice>, the testing of
which made me want to have a generic way to obtain a test database.

Thanks to Mark Lawrence for discussing this module with me, and
sending me an alternative implementation to show me what he needed.

Thanks to Kristian Koehntopp for helping me write a mysql driver,
and to Greg Sabino Mullane for writing a full Postgres driver,
none of which made it into the final release because of the complete
change in goals and implementation between versions 0.02 and 0.03.

The work leading to the new implementation (version 0.99 and later)
was carried on during the Perl QA Hackathon, held in Birmingham in March
2009. Thanks to Birmingham.pm for organizing it and to Booking.com for
sending me there.

=head1 COPYRIGHT

Copyright 2008-2009 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

