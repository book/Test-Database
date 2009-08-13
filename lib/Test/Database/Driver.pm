package Test::Database::Driver;
use strict;
use warnings;
use Carp;
use File::Spec;
use File::Path;
use version;
use YAML::Tiny qw( LoadFile DumpFile );
use Cwd;

use Test::Database::Handle;

#
# GLOBAL CONFIGURATION
#

# the location where all drivers-related files will be stored
my $root
    = File::Spec->rel2abs(
    File::Spec->catdir( File::Spec->tmpdir(), 'Test-Database-' . getlogin() )
    );

# generic driver class initialisation
sub __init {
    my ($class) = @_;

    # create directory if needed
    my $dir = $class->base_dir();
    if ( !-e $dir ) {
        mkpath( [$dir] );
    }
    elsif ( !-d $dir ) {
        croak "$dir is not a directory. Initializing $class failed";
    }

    # load the DBI driver (may die)
    DBI->install_driver( $class->name() );
}

#
# METHODS
#
sub new {
    my ( $class, %args ) = @_;

    if ( $class eq __PACKAGE__ ) {
        if ( exists $args{driver_dsn} ) {
            my ( $scheme, $driver, $attr_string, $attr_hash, $driver_dsn )
                = DBI->parse_dsn( $args{driver_dsn} );
            $args{dbd} = $driver;
        }
        croak "dbd or driver_dsn parameter required" if !exists $args{dbd};
        eval "require Test::Database::Driver::$args{dbd}"
            or do { $@ =~ s/ at .*?\z//s; croak $@; };
        $class = "Test::Database::Driver::$args{dbd}";
        $class->__init();
    }

    my $self = bless {
        username => '',
        password => '',
        %args,
        dbd => $class->name() || $args{dbd},
        },
        $class;

    $self->_load_mapping();

    # try to connect before returning the object
    if ( !$class->is_filebased() ) {
        eval { DBI->connect_cached( $self->connection_info() ) }
            or return;
    }

    return $self;
}

sub _mapping_file {
    return File::Spec->catfile( $_[0]->base_dir(), 'mapping.yml' );
}

sub available_dbname {
    my ($self) = @_;
    my $name = $self->_basename();
    my %taken = map { $_ => 1 } $self->databases();
    my $n = 0;
    $n++ while $taken{"$name$n"};
    return "$name$n";
}

sub _load_mapping {
    my ($self, $file)= @_;
    $file = $self->_mapping_file() if ! defined $file;

    # basic mapping info
    $self->{mapping} = {};
    return if !-e $file;

    # load mapping from file
    my $mapping = LoadFile( $file );
    $self->{mapping} = $mapping->{$self->driver_dsn()} || {};
}

sub _save_mapping {
    my ($self, $file )= @_;
    $file = $self->_mapping_file() if ! defined $file;

    # update mapping information
    my $mapping = {};
    $mapping = LoadFile( $file ) if -e $file;
    $mapping->{ $self->driver_dsn() } = $self->{mapping};

    # save mapping information
    DumpFile( "$file.tmp", $mapping );
    rename "$file.tmp", $file
        or croak "Can't rename $file.tmp to $file: $!";
}

sub make_handle {
    my ($self) = @_;
    my $handle;

    # return a handle for this driver, using the mapping
    if ( my $dbname = $self->{mapping}{ cwd() } ) {
        $handle = Test::Database::Handle->new(
            dsn    => $self->dsn($dbname),
            name   => $dbname,
            driver => $self,
        );
    }

    # otherwise create the database and update the mapper
    else {
        $handle = $self->create_database();
        $self->{mapping}{ cwd() } = $handle->{name};
        $self->_save_mapping();
    }

    return $handle;
}

#
# ACCESSORS
#
sub name { return ( $_[0] =~ /^Test::Database::Driver::([:\w]*)/g )[0]; }
*dbd = \&name;

sub base_dir {
    my ($self) = @_;
    my $class = ref $self || $self;
    return $root if $class eq __PACKAGE__;
    my $dir = File::Spec->catdir( $root, $class->name() );
    return $dir if !ref $self;    # class method
    return $self->{base_dir} ||= $dir;    # may be overriden in new()
}

sub version {
    no warnings;
    return $_[0]{version} ||= version->new( $_[0]->_version() );
}

sub driver_dsn { return $_[0]{driver_dsn} ||= $_[0]->_driver_dsn() }
sub username { return $_[0]{username} }
sub password { return $_[0]{password} }

sub connection_info {
    return ( $_[0]->driver_dsn(), $_[0]->username(), $_[0]->password() );
}

# THESE MUST BE IMPLEMENTED IN THE DERIVED CLASSES
sub drop_database { die "$_[0] doesn't have a drop_database() method\n" }
sub _version      { die "$_[0] doesn't have a _version() method\n" }
sub dsn           { die "$_[0] doesn't have a dsn() method\n" }

# create_database creates the database and returns a handle
sub create_database {
    my $class = ref $_[0] || $_[0];
    goto &_filebased_create_database if $class->is_filebased();
    die "$class doesn't have a create_database() method\n";
}

sub databases {
    goto &_filebased_databases if $_[0]->is_filebased();
    die "$_[0] doesn't have a databases() method\n";
}

# THESE MAY BE OVERRIDDEN IN THE DERIVED CLASSES
sub is_filebased {0}
sub _driver_dsn    { join ':', 'dbi', $_[0]->name(), ''; }

#
# PRIVATE METHODS
#
sub _basename { return lc 'TDD_' . $_[0]->name() . '_' }

# generic implementations for file-based drivers
sub _filebased_databases {
    my ($self)   = @_;
    my $dir      = $self->base_dir();
    my $basename = qr/^@{[$self->_basename()]}/;

    opendir my $dh, $dir or croak "Can't open directory $dir for reading: $!";
    my @databases = grep {/$basename/} File::Spec->no_upwards( readdir($dh) );
    closedir $dh;

    return @databases;
}

sub _filebased_create_database {
    my ( $self ) = @_;
    my $dbname = $self->available_dbname();

    return Test::Database::Handle->new(
        dsn    => $self->dsn($dbname),
        name   => $dbname,
        driver => $self,
    );
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

    sub _version {
        my ($class) = @_;
        ...;
        return $version;
    }

    sub create_database {
        my ( $self ) = @_;
        ...;
        return $handle;
    }

    sub drop_database {
        my ( $self, $name ) = @_;
        ...;
    }

    sub databases {
        my ($self) = @_;
        ...;
        return @databases;
    }

=head1 DESCRIPTION

C<Test::Database::Driver> is a base class for creating C<Test::Database>
drivers.

=head1 METHODS

The class provides the following methods:

=over 4

=item new( %args )

Create a new C<Test::Database::Driver> object.

If called as C<< Test::Database::Driver->new() >>, requires a C<driver>
parameter to define the actual object class.

=item make_handle()

Create a new C<Test::Database::Handle> object, attached to an existing database
or to a newly created one.

The decision whether to create a new database or not is made by
C<Test::Database::Driver> based on the information in the mapper.
See L<TEMPORARY STORAGE ORGANIZATION> for details.

=item name()

=item dbd()

The driver's short name (everything after C<Test::Database::Driver::>).

=item base_dir()

The directory where the driver should store all the files for its databases,
if needed. Typically used by file-based database drivers.

=item version()

C<version> object representing the version of the underlying database enginge.
This object is build with the return value of C<_version()>.

=item driver_dsn()

Return a driver Data Source Name, sufficient to connect to the database
engine without specifying an actual database.

=item username()

Return the connection username.

=item password()

Return the connection password.

=item connection_info()

Return the connection information triplet (C<driver_dsn>, C<username>,
C<password>).

=back

The class also provides a few helpful commands that may be useful for driver
authors:

=over 4

=item available_dbname()

Return an unused database name that can be used to create a new database
for the driver.

=item dsn( $dbname )

Return a bare Data Source Name, for the database with the given C<$dbname>.

=back

=head1 WRITING A DRIVER FOR YOUR DATABASE OF CHOICE

The L<SYNOPSIS> contains a good template for writing a
C<Test::Database::Driver> class.

Creating a driver requires writing the following methods:

=over 4

=item _version()

Return the version of the underlying database engine.

=item create_database( $name )

Create the database for the corresponding DBD driver.

Return a C<Test::Database::Handle> in case of success, and nothing in
case of failure to create the database.

=item drop_database( $name )

Drop the database named C<$name>.

=back

Some methods have defaults implementations in C<Test::Database::Driver>,
but those can be overridden in the derived class:

=over 4

=item is_filebased()

Return a boolean value indicating if the database engine is file-based
or not, i.e. if all the database information is stored in a file or a
directory, and no external database server is needed.

=item databases()

Return the names of all existing databases for this driver as a list
(the default implementation is only valid for file-based drivers).

=back

=head1 TEMPORARY STORAGE ORGANIZATION

Subclasses of C<Test::Database::Driver> store useful information
in the system's temporary directory, under a directory named
F<Test-Database-$user> (C<$user> being the current user's name).

That directory contains the following files:

=over 4

=item database files

The database files and directories created by file-based drivers
controlled by C<Test::Database> are stored here, under names matching
F<tdd_B<DRIVER>_B<N>>, where B<DRIVER> is the lowercased name of the
driver and B<N> is a number.

=item the F<mapping.yml> file

A YAML file containing a C<cwd()> / database name mapping, to enable a
given test suite to receive the same database handles in all the test
scripts that call the C<Test::Database->handles()> method.

=back

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book@cpan.org> >>

=head1 COPYRIGHT

Copyright 2008-2009 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

