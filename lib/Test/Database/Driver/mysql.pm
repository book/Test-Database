package Test::Database::Driver::mysql;
use strict;
use warnings;

use Test::Database::Driver;
our @ISA = qw( Test::Database::Driver );

use Carp;
use File::Spec;
use DBI;

__PACKAGE__->init();

sub setup_engine {
    my ($class) = @_;
    my $dir = $class->base_dir();
    my $config;

    # is there a my.cnf file already?
    my $cnf = File::Spec->catfile( $dir, 'my.cnf' );
    if ( !-e $cnf ) {
        open my $fh, '>', $cnf or croak "Unable to open $cnf for writing: $!";
        $config = {
            datadir  => $dir,
            socket   => File::Spec->catfile( $dir, 'mysqld.sock' ),
            pid_file => File::Spec->catfile( $dir, 'mysqld.pid' ),
            port     => $class->available_port(),
            cnf      => $cnf,
        };
        print {$fh} << "CNF";
[mysqld]
datadir   = $config->{datadir}
socket    = $config->{socket}
pid-file  = $config->{pid_file}
port      = $config->{port}
log-error = mysqld.err
[client]
socket    = $config->{socket}
port      = $config->{port}
CNF
        close $fh;
    }
    else {

        # read the file we just wrote
        # FIXME - should I depend on Config::Tiny for this?
        open my $fh, $cnf or croak "Unable to open $cnf for reading: $!";

        $config = { cnf => $cnf };
        my $section;
        while (<$fh>) {
            chomp;
            if (/\[(\w+)\]/) { $section = $1 }
            elsif ( $section eq 'mysqld' && /([-\w]+)\s*=\s*(.*)/ ) {
                $config->{$1} = $2;
            }
        }
        close $fh;
    }

    # assume system tables are here if 'mysql' directory exists
    if ( !-e File::Spec->catdir( $class->base_dir(), 'mysql' ) ) {
        $class->run_cmd( 'mysql_install_db', "--defaults-file=$cnf" );
    }

    # return the configuration information
    return $config;
}

sub start_engine {
    my ( $class, $config ) = @_;

    # is the server already started?
    if (   !-e $config->{pid_file} || !-e $config->{socket} ) {

        # spawn a new mysqld process (must fork)
        $class->spawn_cmd( 'mysqld_safe', "--defaults-file=$config->{cnf}" );

        # wait until the server has started
        my $i = 0;
        sleep 1 while ! -e $config->{socket} && $i < 10;
    }

    return $config;
}

sub stop_engine {
    my ( $class, $config ) = @_;

    $class->run_cmd(
        'mysqladmin',  "--defaults-file=$config->{cnf}",
        '--user=root', 'shutdown'
    );
}

sub create_database {
    my ( $class, $config, $dbname ) = @_;

    my $dsn = join ';', 'dbi:mysql:host=localhost', "port=$config->{port}",
        "mysql_read_default_file=$config->{cnf}";

    # check if the requested database exists
    if ( !-e File::Spec->catdir( $class->base_dir(), $dbname ) ) {
        my $dbh = DBI->connect( $dsn, 'root', '' );
        $dbh->do( "CREATE DATABASE $dbname" );
    }

    # return the handle
    return Test::Database::Handle->new(
        dsn      => "$dsn;database=$dbname",
        username => $class->username(),
    );
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

=head1 COPYRIGHT

Copyright 2008 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

