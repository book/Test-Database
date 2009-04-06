package Test::Database::Driver::Pg;
use strict;
use warnings;
use Carp;

use Test::Database::Driver;
our @ISA = qw( Test::Database::Driver );

sub _version {
    DBI->connect_cached( $_[0]->connection_info() )
        ->selectcol_arrayref('SELECT VERSION()')->[0] =~ /^PostgreSQL (\S+) /;
    return $1;
}

sub _bare_dsn {
    return 'dbi:Pg:' . join ';',
        map ( {"$_=$_[0]->{$_}"} grep { $_[0]->{$_} } qw( host port ) ),
        'dbname=postgres';
}

sub dsn {
    my ( $self, $dbname ) = @_;
    return 'dbi:Pg:' . join ';',
        map( {"$_=$_[0]->{$_}"} grep { $_[0]->{$_} } qw( host port ) ),
        "dbname=$_[1]";
}

sub essentials {qw< host port username password >}

sub create_database {
    my ( $self, $dbname, $keep ) = @_;
    $dbname = $self->available_dbname() if !$dbname;
    croak "Invalid database name '$dbname'" if $dbname !~ /^\w+$/;

    # create the database if it doesn't exist
    if ( !grep { $_ eq $dbname } $self->databases() ) {
        my $dbh = DBI->connect_cached( $self->connection_info() );
        $dbh->do( "CREATE DATABASE $dbname" );
    }

    $self->register_drop($dbname) if !$keep;

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
    return if !grep { $_ eq $dbname } $self->databases();

    croak "Invalid database name '$dbname'" if $dbname !~ /^\w+$/;
    my $dbh = DBI->connect_cached( $self->connection_info() );
    $dbh->do( "DROP DATABASE $dbname" );
}

sub databases {
    my ($self) = @_;
    my $databases = eval {
        DBI->connect_cached( $self->connection_info() )
            ->selectall_arrayref(
            'SELECT datname FROM pg_catalog.pg_database');
    };
    return grep { $_ !~ /^(?:postgres|template\d*)/ } map {@$_} @$databases;
}

sub cleanup {
    my ($self) = @_;
    my $basename = qr/@{[$self->_basename()]}/;
    $self->drop_database($_) for grep {/$basename/} $self->databases();
}

'Pg';

__END__

=head1 NAME

Test::Database::Driver::Pg - A Test::Database driver for Pg

=head1 SYNOPSIS

    use Test::Database;
    my $dbh = Test::Database->dbh( 'Pg' );

=head1 DESCRIPTION

This module is the C<Test::Database> driver for C<DBD::Pg>.

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

