use strict;
use warnings;
use Test::More;
use Test::Database::Driver;

# fake the databases() method
my @db;
{
    no strict;
    @{"Test::Database::Driver::Zlonk::ISA"} = qw( Test::Database::Driver );
    *{"Test::Database::Driver::Zlonk::databases"} = sub {@db};
}

my $dbname   = "tdd_zlonk_";
my @names    = map {"$dbname$_"} 0, 1, 3, 2, 4;
my @expected = map {"$dbname$_"} 0, 1, 2, 2, 4, 5;

plan tests => 1 + @expected;

is( Test::Database::Driver::Zlonk->_basename(),
    $dbname, "_basename = $dbname" );

for my $expected (@expected) {
    is( Test::Database::Driver::Zlonk->available_dbname(),
        $expected, "available_dbname() = $expected" );
    push @db, shift @names;
}

