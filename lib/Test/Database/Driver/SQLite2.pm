package Test::Database::Driver::SQLite2;
use strict;
use warnings;

use Test::Database::Driver;
our @ISA = qw( Test::Database::Driver );

use DBI;
use File::Spec;

sub is_filebased {1}

sub _version { return DBI->connect( $_[0]->driver_dsn() )->{sqlite_version}; }

sub dsn {
    my ( $self, $dbname ) = @_;
    return 'dbi:SQLite2:dbname='
        . File::Spec->catdir( $self->base_dir(), $dbname );
}

sub drop_database {
    my ( $self, $dbname ) = @_;
    my $dbfile = File::Spec->catfile( $self->base_dir(), $dbname );
    unlink $dbfile;
}

'SQLite2';

__END__

=head1 NAME

Test::Database::Driver::SQLite2 - A Test::Database driver for SQLite2

=head1 SYNOPSIS

    use Test::Database;
    my @handles = Test::Database->handles( 'SQLite2' );

=head1 DESCRIPTION

This module is the C<Test::Database> driver for C<DBD::SQLite2>.

=head1 SEE ALSO

L<Test::Database::Driver>

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book@cpan.org> >>

=head1 COPYRIGHT

Copyright 2008-2009 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

