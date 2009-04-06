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

sub _bare_dsn {
    return 'dbi:mysql:' . join ';',
        map {"$_=$_[0]->{$_}"} grep { exists $_[0]->{$_} } qw( host port );
}

sub dsn {
    return 'dbi:mysql:' . join ';',
        map( {"$_=$_[0]->{$_}"} grep { exists $_[0]->{$_} } qw( host port ) ),
        "database=$_[1]";
}

sub essentials {qw< host port username password >}

sub create_database {
    my ( $self, $dbname, $keep ) = @_;
    $dbname = $self->available_dbname() if !$dbname;

    # create the database if it doesn't exist
    $self->drh()
        ->func( 'createdb', $dbname,
        join( ':', $self->{host}, $self->{port} ),
        $self->{username}, $self->{password}, 'admin' );
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
    $self->drh()
        ->func( 'dropdb', $dbname, join( ':', $self->{host}, $self->{port} ),
        $self->{username}, $self->{password}, 'admin' )
        if grep { $_ eq $dbname } $self->databases();
}

sub databases {
    my ($self) = @_;
    my $databases = eval {
        DBI->connect_cached( $self->connection_info() )
            ->selectall_arrayref('SHOW DATABASES');
    };
    return
        grep { $_ !~ /^(?:information_schema|mysql)/ } map {@$_} @$databases;
}

sub cleanup {
    my ($self) = @_;
    my $basename = qr/@{[$self->_basename()]}/;
    $self->drop_database($_) for grep {/$basename/} $self->databases();
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

