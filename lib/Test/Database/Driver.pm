package Test::Database::Driver;
use strict;
use warnings;
use Carp;

use File::Spec;

#
# global configuration
#
my $root = File::Spec->catdir( File::Spec->tmpdir(),
    'Test-Database-' . getlogin() );

#
# base implementations
#

# MAY be implemented in the derived class
sub start_engine { }
sub stop_engine  { }

# MUST be implemented in the derived class
sub create_database {
    my ( $class, $name ) = @_;

    croak "$class doesn't define a create_database() method."
        . " Can't create database '$name'";
}

#
# common methods
#
sub name { return ( $_[0] =~ /^Test::Database::Driver::(.*)/g )[0]; }

sub base_dir { return File::Spec->catdir( $root, $_[0]->name() ); }

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

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book@cpan.org> >>

=head1 COPYRIGHT

Copyright 2008 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

