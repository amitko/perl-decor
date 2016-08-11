##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Shared::Net::Protocols;
use strict;
use Exporter;
use Exception::Sink;
use Data::Tools::Socket;
use Data::Lock qw( dlock dunlock );

our @ISA    = qw( Exporter );
our @EXPORT = qw(
                  socket_read
                  socket_write
                  socket_print

                  socket_read_message
                  socket_write_message
                );

my %PROTOCOL_TYPES = (
                  'p' => {
                         'require' => 'Storable',
                         'pack'    => \&protocol_type_storable_pack, 
                         'unpack'  => \&protocol_type_storable_pack,
                         }
                  's' => {
                         'require' => 'Data::Stacker',
                         'pack'    => \&protocol_type_stacker_pack, 
                         'unpack'  => \&protocol_type_stacker_pack,
                         }
                  'j' => {
                         'require' => 'JSON',
                         'pack'    => \&protocol_type_json_pack, 
                         'unpack'  => \&protocol_type_json_pack,
                         }
                  );

dlock \%PROTOCOL_TYPES;

my %PROTOCOL_ALLOW = map { $_ => 1 } keys %PROTOCOL_TYPES;

sub de_net_protocol_read_message
{
  my $socket  = shift;
  my $timeout = shift;
  
  my $data = socket_read_message( $socket, $timeout );
  
  my $ptype = substr( $data, 0, 1 );
  boom "unknown or forbidden PROTOCOL_TYPE requested [$ptype] expected one of [" . join( ',', keys %PROTOCOL_ALLOW ) . "]" unless exists $PROTOCOL_ALLOW{ $ptype };
  my $proto = $PROTOCOL_TYPES{ $ptype };

  my $hr = $proto->{ 'unpack' }->( substr( $data, 1 ) );
  boom "invalid data received from socket stream, expected HASH reference" unless ref( $hr ) eq 'HASH';

  return $hr;
}

sub de_net_protocol_write_message
{
  my $socket  = shift;
  my $ptype   = shift;
  my $hr      = shift;
  my $timeout = shift;
  
  boom "unknown or forbidden PROTOCOL_TYPE requested [$ptype] expected one of [" . join( ',', keys %PROTOCOL_ALLOW ) . "]" unless exists $PROTOCOL_ALLOW{ $ptype };
  my $proto = $PROTOCOL_TYPES{ $ptype };
  
  return socket_write_message( $socket, $proto->{ 'pack' }->( $hr ), $timeout );
}

#-----------------------------------------------------------------------------

sub de_net_protocols_allow
{
  %PROTOCOL_ALLOW = ();
  my @p = split //, join '', @_;
  for my $ptype ( @p )
    {
    if( $ptype eq '*' )
      {
      %PROTOCOL_ALLOW = map { $_ => 1 } keys %PROTOCOL_TYPES;
      return;
      }
    boom "unknown or forbidden PROTOCOL_TYPE requested [$ptype] expected one of [" . join( ',', keys %PROTOCOL_ALLOW ) . "]" unless exists $PROTOCOL_ALLOW{ $ptype };
    $PROTOCOL_ALLOW{ $ptype }++;
    }
}

my %PROTOCOL_LOADED;
sub load_protocols
{
  my $ptype = shift;
  boom "unknown or forbidden PROTOCOL_TYPE requested [$ptype] expected one of [" . join( ',', keys %PROTOCOL_ALLOW ) . "]" unless exists $PROTOCOL_ALLOW{ $ptype };
  return if $PROTOCOL_LOADED{ $ptype };
  eval
    {
    require $PROTOCOL_TYPES{ $ptype }{ 'require' };
    };
  if( $@ )
    {
    boom "cannot load PROTOCOL_TYPE [$ptype] error: $@";
    }
  else
    {
    $PROTOCOL_LOADED{ $ptype }++;
    }  
}

#-----------------------------------------------------------------------------

sub protocol_type_storable_pack
{
  load_protocol( 'p' );
  return Storable::nfreeze( shift );
}

sub protocol_type_storable_unpack
{
  load_protocol( 'p' );
  return Storable::thaw( shift );
}

sub protocol_type_stacker_pack
{
  load_protocol( 's' );
  return Data::Stacker::stack_data( shift );
}

sub protocol_type_stacker_unpack
{
  load_protocol( 's' );
  return Data::Stacker::unstack_data( shift );
}

sub protocol_type_json_pack
{
  load_protocol( 'j' );
  return JSON::encode_json( shift );
}

sub protocol_type_json_unpack
{
  load_protocol( 'j' );
  return JSON::decode_json( shift );
}

1;
