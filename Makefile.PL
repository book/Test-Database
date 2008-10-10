use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Test::Database',
    AUTHOR              => 'Philippe Bruhat (BooK) <book@cpan.org>',
    VERSION_FROM        => 'lib/Test/Database.pm',
    ABSTRACT_FROM       => 'lib/Test/Database.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'DBI'        => 1,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Test-Database-*' },
);
