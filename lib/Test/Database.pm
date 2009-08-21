package Test::Database;
use warnings;
use strict;

use File::HomeDir;
use File::Spec;
use DBI;
use Carp;

use Test::Database::Util;
use Test::Database::Driver;
use Test::Database::Handle;

our $VERSION = '1.03';

#
# global configuration
#

# internal data structures
my @HANDLES;
my @DRIVERS;

# driver information
my @DRIVERS_OUR;
my @DRIVERS_OK;

# find the list of all drivers we support
sub load_drivers {
    my %seen;
    for my $dir (@INC) {
        opendir my $dh, File::Spec->catdir( $dir, qw( Test Database Driver ) )
            or next;
        $seen{$_}++ for map { s/\.pm$//; $_ } grep {/\.pm$/} readdir $dh;
        closedir $dh;
    }

    # drivers we support
    @DRIVERS_OUR = sort keys %seen;

    # available DBI drivers
    my %DRIVERS_DBI = map { $_ => 1 } DBI->available_drivers();

    # supported
    @DRIVERS_OK = grep { exists $DRIVERS_DBI{$_} } @DRIVERS_OUR;

    # automatically load all drivers in @DRIVERS_OK
    # (but ignore compilation errors)
    eval "require Test::Database::Driver::$_" for @DRIVERS_OK;

    # actual driver objects
    @DRIVERS = map {
        my $driver;
        eval { $driver = Test::Database::Driver->new( dbd => $_ ); 1; }
            or warn "$@\n";
        $driver || ();
        }
        grep { "Test::Database::Driver::$_"->is_filebased() } @DRIVERS_OK;
}

# startup configuration
__PACKAGE__->load_drivers();
__PACKAGE__->load_config() if -e _rcfile();

#
# private functions
#
# location of our resource file
sub _rcfile {
    File::Spec->catfile( File::HomeDir->my_data(), '.test-database' );
}

#
# methods
#
sub clean_config {
    @HANDLES = ();
    @DRIVERS = ();
}

sub load_config {
    my ( $class, @files ) = @_;
    @files = ( _rcfile() ) if !@files;

    # fetch the items (dsn, driver_dsn) from the config files
    my @items = map { _read_file($_) } @files;

    # create the handles
    push @HANDLES,
        map { Test::Database::Handle->new(%$_) }
        grep { exists $_->{dsn} } @items;

    # create the handles
    push @DRIVERS,
        map { Test::Database::Driver->new(%$_) }
        grep { exists $_->{driver_dsn} } @items;
}

sub list_drivers {
    my ( $class, $type ) = @_;
    $type ||= '';
    return
          $type eq 'all'       ? @DRIVERS_OUR
        : $type eq 'available' ? @DRIVERS_OK
        :                        map { $_->name() } @DRIVERS;
}

sub drivers { @DRIVERS }

# requests for handles
sub handles {
    my ( $class, @requests ) = @_;
    my @handles;

    # empty request means "everything"
    return @handles = ( @HANDLES, map { $_->make_handle() } @DRIVERS )
        if !@requests;

    # turn strings (driver name) into actual requests
    @requests = map { (ref) ? $_ : { dbd => $_ } } @requests;

    # process parameter aliases
    $_->{dbd} ||= delete $_->{driver} for @requests;

    # get the matching handles
    for my $handle (@HANDLES) {
        my $ok;
        my $driver = $handle->{driver};
        for my $request (@requests) {
            next if $request->{dbd} ne $handle->dbd();
            if ( grep /^version(?:_m(?:ax|in))$/, keys %$request ) {
                next if !$driver || !$driver->version_matches($request);
            }
            $ok = 1;
            last;
        }
        push @handles, $handle if $ok;
    }

    # get the matching drivers
    my @drivers;
    for my $driver (@DRIVERS) {
        my $ok;
        for my $request (@requests) {
            next if $request->{dbd} ne $driver->dbd();
            next if !$driver->version_matches($request);
            $ok = 1;
            last;
        }
        push @drivers, $driver if $ok;
    }

    # get a new database handle from the drivers
    push @handles, map { $_->make_handle() } @drivers;

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

=item list_drivers( [$type] )

Return a list of driver names of the given "type".

C<all> returns the list of all existing C<Test::Database::Driver> subclasses.

C<available> returns the list of C<Test::Database::Driver> subclasses for which the matching
C<DBD> class is available.

Called with no parameter (or anything not matching C<all> or C<available>), it will return
the list of currently loaded drivers.

=item drivers()

Returns the C<Test::Database::Driver> instances that are setup by
C<load_drivers()> and updated by C<load_config()>.

=item load_drivers()

Load the available drivers from the system (file-based drivers, usually).

=item load_config( @files )

Read configuration from the files in C<@files>.

If no file is provided, the local equivalent of F<~/.test-database> is used.

=item clean_config()

Empties whatever configuration has already been loaded.
Also removes the loaded drivers list.

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

If missing, all available drivers will match.

=item *

C<version>: exact database engine version

Only database engines having a version number identical to the
given version will match.

=item *

C<min_version>: minimum database engine version

Only database engines having a version number greater or equal to the
given minimum version will match.

=item *

C<max_version>: maximum database engine version

Only database engines having a version number lower (and not equal) to the
given maximum version will match.

=back

A request can also consist of a single string, in which case it is
interpreted as a shortcut for C<{ dbd => $string }>.

=head1 FILES

The list of available, authorized DSN is stored in the local equivalent
of F<~/.test-database>. It's a simple list of key/value pairs, with the
C<dsn> or C<driver_dsn> keys being used to split successive entries:

    # mysql
    dsn      = dbi:mysql:database=mydb;host=localhost;port=1234
    username = user
    password = s3k r3t
    
    # DBD::CSV
    dsn      = dbi:CSV:f_dir=test-db
    
    # sqlite
    dsn      = dbi:SQLite:db.sqlite

    # a "driver" with full access (create/drop databases)
    driver_dsn = dbi:mysql:
    username   = root

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

Write a Cookbook/Tutorial to make adoption easier for testers and module
authors.

=item *

Add a database engine autodetection script/module, to automatically
write the F<.test-database> configuration file.

=item *

Include drivers in the F<.test-database> file.

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

