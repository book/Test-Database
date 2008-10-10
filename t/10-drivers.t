use strict;
use warnings;
use Test::More;
use Test::Database;
use File::Spec;
use DBI;
use List::Util qw( shuffle );

# hardcoded sorted list of our drivers
my @available_drivers = qw( CSV DBM SQLite );

plan tests => 2 + 4 * @available_drivers;

# intersection with DBI->available_drivers
my %available_drivers = map { $_ => 1 } @available_drivers;
my @drivers
    = sort grep { exists $available_drivers{$_} } DBI->available_drivers;

is_deeply( [ Test::Database->available_drivers() ],
    \@available_drivers, 'available_drivers()' );
is_deeply( [ Test::Database->drivers() ], \@drivers, 'drivers()' );

my @will;
my @wont = qw( Zapeth );
for my $name ( Test::Database->available_drivers() ) {
    use_ok("Test::Database::Driver::$name");

    is( "Test::Database::Driver::$name"->name(),
        $name, "$name driver knows its name" );

    like(
        "Test::Database::Driver::$name"->base_dir(),
        qr/Test-Database-.*\Q$name\E/,
        "$name\'s base_dir() looks like expected"
    );

    push @will, $name;
    is_deeply( [ Test::Database->drivers( shuffle @will, @wont ) ],
        \@will, 'drivers() returned the requested selection of drivers' );
}

