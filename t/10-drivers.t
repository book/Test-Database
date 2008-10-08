use strict;
use warnings;
use Test::More;
use Test::Database;

plan tests => 2;

is_deeply( [ Test::Database->available_drivers() ], [], 'No drivers yet' );
is_deeply( [ Test::Database->drivers() ], [], 'No drivers yet' );

