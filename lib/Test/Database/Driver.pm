package Test::Database::Driver;
use strict;
use warnings;
use Carp;
use File::Spec;
use File::Path;
use POSIX qw( WIFEXITED WEXITSTATUS WIFSIGNALED WTERMSIG );

use Test::Database::Handle;

#
# global configuration
#
my $root = File::Spec->rel2abs(
    File::Spec->catdir(
        File::Spec->tmpdir(), 'Test-Database-' . __PACKAGE__->username()
    )
);

__PACKAGE__->init();

#
# base implementations
#

sub init {
    my ($class) = @_;
    my $dir = $class->base_dir();
    if ( !-e $dir ) {
        mkpath $dir;
    }
    elsif ( !-d $dir ) {
        croak "$dir is not a directory. Initializing $class failed";
    }
}

# some information methods
my %setup;
my %started;
sub is_engine_setup   { return exists $setup{ $_[0] } }
sub is_engine_started { return exists $started{ $_[0] } }

# MAY be implemented in the derived class
sub setup_engine { }
sub start_engine { }
sub stop_engine  { }

# MUST be implemented in the derived class
sub create_database {
    my ( $class, $config, $name ) = @_;

    croak "$class doesn't define a create_database() method."
        . " Can't create database '$name'";
}

#
# common methods
#
sub username { return getlogin() }

sub name { return ( $_[0] =~ /^Test::Database::Driver::(.*)/g )[0]; }

sub base_dir {
    return $_[0] eq __PACKAGE__
        ? $root
        : File::Spec->catdir( $root, $_[0]->name() );
}

sub cleanup { rmtree $_[0]->base_dir() }

my %handle;

sub handle {
    my ( $class, $name ) = @_;

    $name ||= 'test_database';

    # make sure the database server has been setup
    $setup{$class} = $class->setup_engine() if !$class->is_engine_setup();

    # make sure the database server has been started
    $started{$class} = $class->start_engine( $setup{$class} )
        if !$class->is_engine_started();

    # return the cached handle
    return $handle{$class}{$name}
        ||= $class->create_database( $setup{$class}, $name );
}

# stop all database engines that were started
END {
    $_->stop_engine( $started{$_} )
        for grep { $_->is_engine_started() } keys %started;
}

#
# useful tools
#
sub run_cmd {
    my ( $class, $cmd, @args ) = @_;

    # call system() with indirect syntax
    system {$cmd} $cmd, @args;

    # error handling
    if ( $? == -1 ) {
        croak "Failed to execute $cmd: $!\n";
    }

    my $status;
    if ( WIFEXITED($?) ) {
        $status = WEXITSTATUS($?);
        croak "$cmd exited with status $status" if $status;
    }

    my $signal;
    if ( WIFSIGNALED($?) ) {
        $signal = WTERMSIG($?);
        croak "$cmd died with signal $signal";
    }

    return;
}

sub spawn_cmd {
    my ( $class, $cmd, @args ) = @_;

    my $ProcessObj;

    if ( $^O eq 'MSWin32' ) {    # the Windows way

        require Win32::Process;
        require Win32;
        no strict 'subs';
        Win32::Process::Create( $ProcessObj, $cmd, "@args", 0,
            NORMAL_PRIORITY_CLASS, '.' )
            || croak Win32::FormatMessage( Win32::GetLastError() );
    }
    else {                       # try the Unix way

        $ProcessObj = fork();
        croak "Cannot fork $cmd: $!" if !defined $ProcessObj;
        if ($ProcessObj) {
            exec {$cmd} $cmd, @args or die "Cannot exec $cmd: $!";
        }
    }

    # either a Win32::Process object or a PID number
    return $ProcessObj;
}

sub available_port {
    my ($class);

    require IO::Socket::INET;
    my $sock = IO::Socket::INET->new(
        PeerAddr => 'localhost',
        PeerPort => 0,
        Proto    => 'tcp',
        Listen   => 1,
    ) or croak "Unable to find an available tcp port: $@";

    my $port = $sock->sockport();
    $sock->close();

    return $port;
}

'CONNECTION';

__END__

=head1 NAME

Test::Database::Driver - Base class for Test::Database drivers

=head1 SYNOPSIS

    package Test::Database::Driver::MyDatabase;
    use strict;
    use warnings;
    
    use Test::Database::Driver;
    our @ISA = qw( Test::Database::Driver );
    
    sub start_server { ... }

    sub stop_server  { ... }

    sub create_database {
        my ( $class, $name ) = @_;
        ...
        return $handle;
    }

=head1 DESCRIPTION

C<Test::Database::Driver> is a base class for creating C<Test::Database>
drivers.

=head1 METHODS

The class provides the following methods:

=over 4

=item name()

The driver's short name (everything after C<Test::Database::Driver::>).

=item base_dir()

The directory where the driver should store all the files for its databases.
Typically used to configure the DSN or the database engine.

=item handle( [ $name ] )

Return a C<Test::Database::Handle> object for a database named C<$name>.
If C<$name> is not given, the name C<test_database> is used.

=item cleanup()

Delete the C<base_dir()> directory and its content.

When called on C<Test::Database> directly, it will delete the main
directory that contains all the individual directories used by
C<Test::Database> drivers.

=back

The class also provides a few helpful commands that may be useful for driver
authors:

=over 4

=item init()

The method does the general configuration needed for a database driver.
All drivers should start by calling C<< __PACKAGE__->init() >> to ensure
they have been correctly initialized.

=item username()

Return the username of the user running the current program.

=item run_cmd( $cmd, @args )

Run the requested command using C<system()>. Will C<die()> in case of
a problem (non-zero exit status, signal).

=item spawn_cmd( $cmd, @args )

Create a new process to run the requested command.
Will C<die()> in case of a problem.

Will use C<fork()>+C<exec()> on Unix systems, and
C<Win32::Process::Create> under Win32 systems.

=item available_port()

Return an available TCP port (useful for setting up a TCP server).

=item is_engine_setup()

=item is_engine_started()

Routines that let the driver know if the engine has been setup or started.
(Used internally.)

=back

=head1 WRITING A DRIVER FOR YOUR DATABASE OF CHOICE

Creating a driver requires writing the following methods:

=over 4

=item setup_engine()

Setup the corresponding database engine, and return a true value
corresponding to the configuration information needed to start the
database engine and to create new databases.

=item start_engine( $config )

Start the corresponding database engine, and return a true value if the
server was successfully started (meaning it will need to be stopped).

C<$config> is the return value from C<setup_engine()>.

C<Test::Database::Driver> provides a default implementation if no startup
is required.

=item stop_engine( $info )

Stops a running database engine.

C<$info> is the return value of C<start_server()>, which allows driver
authors to pass information to the C<stop_engine()> method.

C<Test::Database::Driver> provides a default implementation if no shutdown
is required.

=item create_database( $config, $name )

Create the database for the corresponding DBD driver.

C<$config> is the return value from C<setup_engine()>.

Return a C<Test::Database::Handle> in case of success, and nothing in
case of failure to create the database.

=back

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book@cpan.org> >>

=head1 COPYRIGHT

Copyright 2008 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

