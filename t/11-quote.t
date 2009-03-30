use strict;
use warnings;
use Test::More;
use Test::Database::Driver;

my @strings = (
    'abcdef',
    'ab"cdef',
    'abc def',
    "abc\ndef",
    'abc\def',
    'abc\\def',
    'abc\\\\def',
    'abc\\\\\\def',
);

plan tests => scalar @strings;

for my $string (@strings) {
    my $quoted = Test::Database::Driver::_quote($string);
    is( Test::Database::Driver::_unquote( $quoted ) , $string, $quoted);
}

