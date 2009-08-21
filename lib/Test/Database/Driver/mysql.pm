package Test::Database::Driver::mysql;
use strict;
use warnings;

use DBI;

use Test::Database::Driver;
our @ISA = qw( Test::Database::Driver );

sub _version {
    return DBI->connect( $_[0]->connection_info() )
        ->selectcol_arrayref('SELECT VERSION()')->[0];
}

sub create_database {
    my ( $self ) = @_;
    my $dbname = $self->available_dbname();

    DBI->connect_cached( $self->connection_info() )
        ->do("CREATE DATABASE $dbname");

    # return the handle
    return Test::Database::Handle->new(
        dsn      => $self->dsn($dbname),
        name     => $dbname,
        username => $self->username(),
        password => $self->password(),
        driver   => $self,
    );
}

sub drop_database {
    my ( $self, $dbname ) = @_;

    DBI->connect_cached( $self->connection_info() )
        ->do("DROP DATABASE $dbname")
        if grep { $_ eq $dbname } $self->databases();
}

sub databases {
    my ($self)    = @_;
    my $basename  = qr/^@{[$self->_basename()]}/;
    my $databases = eval {
        DBI->connect_cached( $self->connection_info() )
            ->selectall_arrayref('SHOW DATABASES');
    };
    return grep {/$basename/} map {@$_} @$databases;
}

'mysql';

__END__

=head1 NAME

Test::Database::Driver::mysql - A Test::Database driver for mysql

=head1 SYNOPSIS

    use Test::Database;
    my $dbh = Test::Database->dbh( 'mysql' );

=head1 DESCRIPTION

This module is the C<Test::Database> driver for C<DBD::mysql>.

=head1 SEE ALSO

L<Test::Database::Driver>

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book@cpan.org> >>

=head1 ACKNOWLEDGEMENTS

Many thanks to Kristian Köhntopp who helped me while writing a
previous version of this module (before C<Test::Database> 0.03).

=head1 COPYRIGHT

Copyright 2008-2009 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

