package SQL::Translator::Schema::Field;

# ----------------------------------------------------------------------
# $Id: Field.pm,v 1.4 2003-05-09 17:08:14 kycl4rk Exp $
# ----------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; version 2.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
# 02111-1307  USA
# -------------------------------------------------------------------

=pod

=head1 NAME

SQL::Translator::Schema::Field - SQL::Translator field object

=head1 SYNOPSIS

  use SQL::Translator::Schema::Field;
  my $field = SQL::Translator::Schema::Field->new(
      name => 'foo',
      sql  => 'select * from foo',
  );

=head1 DESCRIPTION

C<SQL::Translator::Schema::Field> is the field object.

=head1 METHODS

=cut

use strict;
use Class::Base;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils 'parse_list_arg';

use base 'Class::Base';
use vars qw($VERSION $TABLE_COUNT $VIEW_COUNT);

$VERSION = 1.00;

# ----------------------------------------------------------------------
sub init {

=pod

=head2 new

Object constructor.

  my $schema = SQL::Translator::Schema::Field->new;

=cut

    my ( $self, $config ) = @_;

    for my $arg ( 
        qw[ 
            table name data_type size is_primary_key is_nullable
            is_auto_increment
        ] 
    ) {
        next unless defined $config->{ $arg };
        $self->$arg( $config->{ $arg } ) or return;
    }
    return $self;
}

# ----------------------------------------------------------------------
sub data_type {

=pod

=head2 data_type

Get or set the field's data type.

  my $data_type = $field->data_type('integer');

=cut

    my $self = shift;
    $self->{'data_type'} = shift if @_;
    return $self->{'data_type'} || '';
}

# ----------------------------------------------------------------------
sub default_value {

=pod

=head2 default_value

Get or set the field's default value.  Will return undef if not defined
and could return the empty string (it's a valid default value), so don't 
assume an error like other methods.

  my $default = $field->default_value('foo');

=cut

    my ( $self, $arg ) = @_;
    $self->{'default_value'} = $arg if defined $arg;
    return $self->{'default_value'};
}

# ----------------------------------------------------------------------
sub is_auto_increment {

=pod

=head2 is_auto_increment

Get or set the field's C<is_auto_increment> attribute.

  my $is_pk = $field->is_auto_increment(1);

=cut

    my ( $self, $arg ) = @_;

    if ( defined $arg ) {
        $self->{'is_auto_increment'} = $arg ? 1 : 0;
    }

    unless ( defined $self->{'is_auto_increment'} ) {
        if ( my $table = $self->table ) {
            if ( my $schema = $table->schema ) {
                if ( 
                    $schema->database eq 'PostgreSQL' &&
                    $self->data_type eq 'serial'
                ) {
                    $self->{'is_auto_increment'} = 1;
                }
            }
        }
    }

    return $self->{'is_auto_increment'} || 0;
}

# ----------------------------------------------------------------------
sub is_nullable {

=pod

=head2 is_nullable

Get or set the whether the field can be null.  If not defined, then 
returns "1" (assumes the field can be null).  The argument is evaluated
by Perl for True or False, so the following are eqivalent:

  $is_nullable = $field->is_nullable(0);
  $is_nullable = $field->is_nullable('');
  $is_nullable = $field->is_nullable('0');

While this is technically a field constraint, it's probably easier to
represent this as an attribute of the field.  In order keep things
consistent, any other constraint on the field (unique, primary, and
foreign keys; checks) are represented as table constraints.

=cut

    my ( $self, $arg ) = @_;

    if ( defined $arg ) {
        $self->{'is_nullable'} = $arg ? 1 : 0;
    }

    return defined $self->{'is_nullable'} ? $self->{'is_nullable'} : 1;
}

# ----------------------------------------------------------------------
sub is_primary_key {

=pod

=head2 is_primary_key

Get or set the field's C<is_primary_key> attribute.  Does not create
a table constraint (should it?).

  my $is_pk = $field->is_primary_key(1);

=cut

    my ( $self, $arg ) = @_;

    if ( defined $arg ) {
        $self->{'is_primary_key'} = $arg ? 1 : 0;
    }

    unless ( defined $self->{'is_primary_key'} ) {
        if ( my $table = $self->table ) {
            if ( my $pk = $table->primary_key ) {
                my %fields = map { $_, 1 } $pk->fields;
                $self->{'is_primary_key'} = $fields{ $self->name } || 0;
            }
            else {
                $self->{'is_primary_key'} = 0;
            }
        }
    }

    return $self->{'is_primary_key'} || 0;
}

# ----------------------------------------------------------------------
sub is_valid {

=pod

=head2 is_valid

Determine whether the field is valid or not.

  my $ok = $field->is_valid;

=cut

    my $self = shift;
    return $self->error('No name')         unless $self->name;
    return $self->error('No data type')    unless $self->data_type;
    return $self->error('No table object') unless $self->table;
    return 1;
}

# ----------------------------------------------------------------------
sub name {

=pod

=head2 name

Get or set the field's name.

  my $name = $field->name('foo');

=cut

    my $self = shift;

    if ( my $arg = shift ) {
        if ( my $table = $self->table ) {
            return $self->error( qq[Can't use field name "$arg": table exists] )
                if $table->get_field( $arg );
        }

        $self->{'name'} = $arg;
    }

    return $self->{'name'} || '';
}

# ----------------------------------------------------------------------
sub order {

=pod

=head2 order

Get or set the field's order.

  my $order = $field->order(3);

=cut

    my ( $self, $arg ) = @_;

    if ( defined $arg && $arg =~ /^\d+$/ ) {
        $self->{'order'} = $arg;
    }

    return $self->{'order'} || 0;
}

# ----------------------------------------------------------------------
sub size {

=pod

=head2 size

Get or set the field's size.  Accepts a string, array or arrayref of
numbers and returns a string.

  $field->size( 30 );
  $field->size( [ 255 ] );
  $size = $field->size( 10, 2 );
  print $size; # prints "10,2"

  $size = $field->size( '10, 2' );
  print $size; # prints "10,2"

=cut

    my $self    = shift;
    my $numbers = parse_list_arg( @_ );

    if ( @$numbers ) {
        my @new;
        for my $num ( @$numbers ) {
            if ( defined $num && $num =~ m/^\d+(?:\.\d+)?$/ ) {
                push @new, $num;
            }
        }
        $self->{'size'} = \@new if @new; # only set if all OK
    }

    return wantarray 
        ? @{ $self->{'size'} }
        : join( ',', @{ $self->{'size'} || [0] } )
    ;
}

# ----------------------------------------------------------------------
sub table {

=pod

=head2 table

Get or set the field's table object.

  my $table = $field->table;

=cut

    my $self = shift;
    if ( my $arg = shift ) {
        return $self->error('Not a table object') unless
            UNIVERSAL::isa( $arg, 'SQL::Translator::Schema::Table' );
        $self->{'table'} = $arg;
    }

    return $self->{'table'};
}

# ----------------------------------------------------------------------
sub DESTROY {
    my $self = shift;
    undef $self->{'table'}; # destroy cyclical reference
}

1;

# ----------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut
