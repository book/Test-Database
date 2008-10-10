package Test::Database::Driver::Bad;
use strict;
use warnings;

use Test::Database::Driver;
our @ISA = qw( Test::Database::Driver );

$INC{'Test/Database/Driver/Bad.pm'} = 1;    # yes, we loaded it!

package main;

use strict;
use warnings;
use Test::More;
use Test::Database;

plan tests => 2;

ok( !eval { Test::Database->handle('Bad'); 1 },
    "Test::Database->handle( 'Bad' ) failed"
);
like(
    $@,
    qr/^Test::Database::Driver::Bad doesn't define a create_database\(\) method. Can't create database 'default'/,
    'Expected error message'
);

