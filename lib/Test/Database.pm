package Test::Database;
use warnings;
use strict;

use File::HomeDir;
use File::Spec;
use DBI;
use Carp;

our $VERSION = '0.03';

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
    $file ||= _rcfile();

    _canonicalize_drivers();
    open my $fh, '>', $file or croak "Can't open $file for writing: $!";
    print $fh map { $_->as_string, "\n" } @DRIVERS;
    close $fh;
}

sub load_drivers {
    my ( $class, $file ) = @_;
    $file ||= _rcfile();

    my %args;
    open my $fh, '<', $file or croak "Can't open $file for reading: $!";
    while (<$fh>) {
        next if /^\s*(?:#|$)/;    # skip blank lines and comments

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
        croak "Can't parse line at $file, line $.:\n$_\n ";
    }
    push @DRIVERS, Test::Database::Driver->new(%args)
        if keys %args;
    close $fh;

    _canonicalize_drivers();
}

sub drivers {
    my ( $class, @requests ) = @_;
    return @DRIVERS if !@requests;

    my @drivers;
    for my $request (@requests) {
        $request = { driver => $request } if !ref $request;
        for my $driver ( grep { $_->{driver} eq $request->{driver} }
            @DRIVERS )
        {
            next
                if exists $request->{min_version}
                    && $driver->{version} < $request->{min_version};
            next
                if exists $request->{max_version}
                    && $driver->{version} > $request->{max_version};
            push @drivers, $driver;
        }
    }

    my %seen;
    return grep { !$seen{$_}++ } @drivers;
}

sub handle {
    my ( $class, $driver, $name ) = @_

    return "Test::Database::Driver::$driver"->handle($name);
}

sub cleanup { Test::Database::Driver->cleanup(); }

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

Return the list of supported DBI drivers.

This is the intersection of the results of
C<< Test::Database->all_drivers() >> and C<< DBI->available_drivers() >>.

=item drivers( @requests )

Return the list of supported DBI drivers that have been detected as installed.

If C<@requests> is provided, only the drivers that match one of the
requests are returned.

=item handle( $driver [, $name ] )

If C<$name> is not provided, the default C<Test::Database::Handle> object
for the driver is provided. No garantees are made on its being empty.

The default database handle is obtained from the local configuration
(stored in the C<Test::Database::MyConfig> module), then from the global
configuration (stored in the C<Test::Database::Config> module). If no
configuration information is available, C<Test::Database> will then try
to create a default temporary database, if the driver supports it.

The database will be created the first time, and and subsequent calls
are garanteed to provide connection information to the same database,
so you can share data between your scripts.

=item dbh( $driver [, $name ] )

=item connection_info( $driver [, $name ] )

=item dsn( $driver [, $name ] )

=item username( $driver [, $name ] )

=item password( $driver [, $name ] )

Shortcut methods for:

    Test::Database->handle( $driver [, $name ] )->dbh();
    Test::Database->handle( $driver [, $name ] )->connection_info();
    Test::Database->handle( $driver [, $name ] )->dsn();
    Test::Database->handle( $driver [, $name ] )->username();
    Test::Database->handle( $driver [, $name ] )->password();

See C<Test::Database::Handle> for details.

=item cleanup()

Remove the directory used by C<Test::Database> drivers.

=back

=head1 EXPORTS

All the methods can be exported as functions (prefixed with C<test_db_>)
using the C<:all> tag.

So you can either do:

    use Test::Database;
    my $dbh = Test::Database->dbh( 'SQLite' );

or:

    use Test::Database qw( :all );
    my $dbh = test_db_dbh( 'SQLite' );

or export only the one you want:

    use Test::Database qw( test_db_dbh );
    my $dbh = test_db_dbh( 'SQLite' );

=cut

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

Allow options to be passed to handle()

At the moment, it's possible to use connection_info() and  pass options
to DBI->connect() directly.

=item *

Allow C<handle()> to be called with no parameter and return
a handle to a test database (need to find an ordering scheme for
the drivers).

=item *

Add support for C<DBI_DSN>. If C<handle()> is called with no parameters,
or if DBI_DSN matches the requested driver, first use this DSN.

=item *

Add support for a C<Test::Database::Config> module, holding system-wide
test database configuration. Probably need to create an interactive way
to set it up.

=back

=head1 ACKNOWLEDGEMENTS

Thanks to C<< <perl-qa@perl.org> >> for early comments.

Thanks to Nelson Ferraz for writing C<DBIx::Slice>, the testing of
which made me want to have a generic way to obtain a test database.

=head1 COPYRIGHT

Copyright 2008 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

