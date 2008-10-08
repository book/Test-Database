package Test::Database;
use warnings;
use strict;

use File::Spec;
use DBI;

our $VERSION = '0.01';

#
# driver information
#
my @DRIVERS;
my @ALL_DRIVERS;
my %DBI_DRIVERS = map { $_ => 1 } DBI->available_drivers();

# find the list of all drivers we support
for my $dir (@INC) {
    opendir my $dh, File::Spec->catdir( $dir, qw< Test Database Driver > )
        or next;
    push @ALL_DRIVERS,
        map { s/\.pm$//; $_ } grep { -f && /\.pm$/ } readdir $dh;
    closedir $dh;
}

@ALL_DRIVERS = sort @ALL_DRIVERS;
@DRIVERS = grep { exists $DBI_DRIVERS{$_} } @ALL_DRIVERS;

sub available_drivers { return @ALL_DRIVERS }
sub drivers           { return @DRIVERS }

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

=head1 METHODS

C<Test::Database> provides the following methods:

=over 4

=item available_drivers()

Return the list of supported DBI drivers.

=item drivers()

Return the list of supported DBI drivers that have been detected as installed.

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

=item handles( [ $name ] )

Return the list of handles associated to C<$name> for all drivers.

=back

=head1 EXPORTS

All the methods can be exported as functions (prefixed with C<test_db_>)
using the C<:functions> tag.

So you can either do:

    use Test::Database;
    my $dbh = Test::Database->dbh( 'SQLite' );

or:

    use Test::Database qw( :functions );
    my $dbh = test_db_dbh( 'SQLite' );

=cut

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book at cpan.org> >>

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


=head1 ACKNOWLEDGEMENTS

Thanks to perl-qa@perl.org for early comments.

Thanks to Nelson Ferraz for C<DBIx::Slice>, the testing of which made
me want to have a generic way to obtain a test database.

=head1 COPYRIGHT

Copyright 2008 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

