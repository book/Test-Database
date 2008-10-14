use strict;
use warnings;
use Test::More;
use Test::Database;
use File::Spec;
use DBI;
use List::Util qw( shuffle );

# hardcoded sorted list of our drivers
my @available_drivers = qw( CSV DBM SQLite mysql );

# intersection with DBI->available_drivers
my %available_drivers = map { $_ => 1 } @available_drivers;
my @drivers
    = sort grep { exists $available_drivers{$_} } DBI->available_drivers;

plan tests => 2 + 3 * @available_drivers + @drivers + 2;

is_deeply( [ Test::Database->available_drivers() ],
    \@available_drivers, 'available_drivers()' );
is_deeply( [ Test::Database->drivers() ], \@drivers, 'drivers()' );

# check all drivers
for my $name ( Test::Database->available_drivers() ) {
    use_ok("Test::Database::Driver::$name");

    is( "Test::Database::Driver::$name"->name(),
        $name, "$name driver knows its name" );

    like(
        "Test::Database::Driver::$name"->base_dir(),
        qr/Test-Database-.*\Q$name\E/,
        "$name\'s base_dir() looks like expected"
    );
}

# test that Test::Database->drivers( @list ) only returns
# the installed drivers from the list
my @will;
my @wont = qw( Zapeth );
is_deeply( [ Test::Database->drivers(@wont) ], \@will,
    "drivers( @wont ) =>" );

for my $name ( Test::Database->drivers() ) {
    push @will, $name;
    my @list = shuffle @will, @wont;
    is_deeply( [ Test::Database->drivers(@list) ],
        \@will, "drivers( @list ) => @will" );
}

my @list = shuffle( Test::Database->available_drivers(), @wont );
is_deeply( [ Test::Database->drivers() ], \@will, "drivers(@list) => @will" );

