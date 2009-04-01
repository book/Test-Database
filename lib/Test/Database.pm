package Test::Database;
use warnings;
use strict;

use File::HomeDir;
use File::Spec;
use DBI;
use Carp;

our $VERSION = '0.99_01';

use Test::Database::Driver;

#
# driver information
#
my @DRIVERS;
my @DRIVERS_OUR;
my %DRIVERS_DBI = map { $_ => 1 } DBI->available_drivers();
my @DRIVERS_OK;

# find the list of all drivers we support
{
    my %seen;
    for my $dir (@INC) {
        opendir my $dh, File::Spec->catdir( $dir, qw< Test Database Driver > )
            or next;
        $seen{$_}++ for map { s/\.pm$//; $_ } grep {/\.pm$/} readdir $dh;
        closedir $dh;
    }
    @DRIVERS_OUR = sort keys %seen;
}

@DRIVERS_OK = grep { exists $DRIVERS_DBI{$_} } @DRIVERS_OUR;

# automatically load all drivers in @DRIVERS_OK
# (but ignore compilation errors)
eval "require Test::Database::Driver::$_" for @DRIVERS_OK;

# load all file-based drivers
push @DRIVERS, map { Test::Database::Driver->new( driver => $_ ) }
    grep { "Test::Database::Driver::$_"->is_filebased() } @DRIVERS_OK;

# load drivers from configuration
__PACKAGE__->load_drivers() if -e _rcfile();

#
# private functions
#
sub _rcfile {
    File::Spec->catfile( File::HomeDir->my_data(), '.test-database' );
}

sub _canonicalize_drivers {
    my %seen;
    @DRIVERS = grep { !$seen{ $_->as_string() }++ } @DRIVERS;
}

#
# methods
#
sub unload_drivers { @DRIVERS = (); }

sub all_drivers { return @DRIVERS_OUR }

sub available_drivers { return @DRIVERS_OK }

sub save_drivers {
    my ( $class, $file ) = @_;
    $file = _rcfile() if !defined $file;

    _canonicalize_drivers();
    open my $fh, '>', $file or croak "Can't open $file for writing: $!";
    print $fh map { $_->as_string, "\n" } @DRIVERS;
    close $fh;
}

sub load_drivers {
    my ( $class, $file ) = @_;
    $file = _rcfile() if !defined $file;

    my %args;
    open my $fh, '<', $file or croak "Can't open $file for reading: $!";
    while (<$fh>) {
        next if /^\s*(?:#|$)/;    # skip blank lines and comments
        chomp;

        /\s*(\w+)\s*=\s*(.*)\s*/ && do {
            my ( $key, $value ) = ( $1, $2 );
            $value = Test::Database::Driver::_unquote( $value )
                 if $value =~ /\A["']/;
            if ( $key eq 'driver' && keys %args ) {
                push @DRIVERS, Test::Database::Driver->new(%args);
                %args = ();
            }
            $args{$key} = $value;
            next;
            };

        # unknown line
        croak "Can't parse line at $file, line $.:\n  <$_>";
    }
    push @DRIVERS, Test::Database::Driver->new(%args)
        if keys %args;
    close $fh;

    _canonicalize_drivers();
}

sub drivers {
    my ( $class, @requests ) = @_;
    return @DRIVERS if !@requests;

    # turn strings (driver name) into actual requests
    @requests = map { (ref) ? $_ : { driver => $_ } } @requests;

    my @drivers;
    for my $request (@requests) {
        for my $driver ( grep { $_->{driver} eq $request->{driver} }
            @DRIVERS )
        {
            next
                if exists $request->{min_version}
                    && $driver->version() < $request->{min_version};
            next
                if exists $request->{max_version}
                    && $driver->version() > $request->{max_version};
            push @drivers, $driver;
        }
    }

    my %seen;
    return grep { !$seen{$_}++ } @drivers;
}

sub handles {
    my ( $class, @requests ) = @_;

    # turn strings (driver name) into actual requests
    @requests = map { (ref) ? $_ : { driver => $_ } } @requests;

    # first filter on the drivers
    my @drivers = $class->drivers(@requests);

    # then on the handles
    return map { $_->handles(@requests) } @drivers;
}

sub cleanup {
    $_->cleanup()
        for map { Test::Database::Driver->new( driver => $_ ) } @DRIVERS_OK;
}

'TRUE';

__END__

=head1 NAME

Test::Database - Database handles ready for testing

=head1 SYNOPSIS

Maybe you need a test database for a specific database driver:

    use Test::Database;

    # connection information
    my ( $dsn, $username, $password )
        = Test::Database->connection_info('SQLite');

    # database handle
    my $dbh = Test::Database->dbh('SQLite');

Maybe you want to use the same test database over several test scripts:

    use Test::Database;

    # connection information
    my ( $dsn, $username, $password )
        = Test::Database->connection_info( SQLite => 'mydb' );

    # database handle
    my $dbh = Test::Database->dbh( SQLite => 'mydb' );

Maybe you wrote generic code you want to test on all available databases:

    use Test::Database;

    my @drivers = Test::Database->drivers();

    for my $driver (@drivers) {
        my $handle = Test::Database->handle( $driver );
    }

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

Typical usage if the module require a specific database:

   use Test::More;
   use Test::Database;

   my $dbh = Test::Database->dbh( SQLite => 'test' );
   plan skip_all => 'No test SQLite database available' if !$dbh;

   # rest of the test script

Typical usage if the module wants to run the test on as many databases
as possible:

    use Test::More;
    use Test::Database;

    for my $handle ( map { Test::Database->handle( $_ => 'test' ) }
        Test::Database->drivers() )
    {
        diag 'Testing on ' . $handle->driver();
        my $dbh = $handle->dbh();

        # rest of the test script
    }

=head1 METHODS

C<Test::Database> provides the following methods:

=over 4

=item all_drivers()

Return the list of supported drivers.

=item available_drivers()

Return the list of supported DBI drivers that are installed.

This is the intersection of the results of
C<< Test::Database->all_drivers() >> and C<< DBI->available_drivers() >>.

=item load_drivers( [ $file ] )

Read the database drivers configuration from the given C<$file> and
load them.

If C<$file> is not given, the local equivalent of F<~/.test-database> is used.

=item save_drivers( [ $file ] )

Saver the available database drivers configuration to the given C<$file>.

If C<$file> is not given, the local equivalent of F<~/.test-database> is used.

=item unload_drivers()

Unload all drivers.

=item drivers( @requests )

Return the C<Test::Database::Driver> objects corresponding to
all the available drivers.

If C<@requests> is provided, only the drivers that match one of the
requests are returned.

See L<REQUESTS> for details about writing requests.

=item handles( @requests )

Return a set of C<Test::Database::Handle> objects that matche the
given C<@requests>.

If C<@requests> is not provided, return a handle for each database
that exists in each driver.

See L<REQUESTS> for details about writing requests.

=item cleanup()

Call the C<cleanup()> method of all available drivers.

=back

=head1 REQUESTS

The C<drivers()>, C<handles()> and C<dbh()> methods tales I<requests>
as parameters. A request is a simple hash reference, with a number of
recognized keys.

Some keys have an effect on driver selection:

=over 4

=item *

C<driver>: driver name

If missing, all available drivers will match.

=item *

C<min_version>: minimum database engine version

Only database engines having at least the given minimum version will match.

=item *

C<max_version>: maximum database engine version

Only database engines having at least the given maximum version will match.

=back

Others have an effect on actual database selection:

=over 4

=item *

C<name>: name of the database to select or create.

If a database of the given name exists in the select database engine,
a handle to it will be returned.

If the field is missing, a new database will be created with an
automatically generated name.

=item *

C<keep>: boolean

By default, database are dropped at the end of the program's life.
If this parameter is true, the database will not be dropped, and
can be selected again using its name.

=back

A request can also consist of a single string, in which case it is
interpreted as a shortcut for C<{ driver => $string }>.

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

Add a database engine autodetection script/module, to automatically
write the F<.test-database> configuration file.

=back

=head1 ACKNOWLEDGEMENTS

Thanks to C<< <perl-qa@perl.org> >> for early comments.

Thanks to Nelson Ferraz for writing C<DBIx::Slice>, the testing of
which made me want to have a generic way to obtain a test database.

Thanks to Mark Lawrence for discussing this module with me, and
sending me an alternative implemenation to show me what he needed.

Thanks to Kristian Koehntopp for helping me write a mysql driver,
and to Greg Sabino Mullane for writing a full Postgres driver,
none of which made it into the final release because of the complete
change in goals and implementation between versions 0.02 and 0.03.

The work leading to the new implementation was carried on during
the Perl QA Hackathon, held in Birmingham in March 2009. Thanks to
Birmingham.pm for organizing it and to Booking.com for sending me
there.

=head1 COPYRIGHT

Copyright 2008-2009 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

