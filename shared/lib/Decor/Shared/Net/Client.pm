##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Shared::Net::Client;
use strict;
use Exporter;
use Exception::Sink;

use Hash::Util qw( lock_ref_keys );
use IO::Socket::INET;
use Data::Tools;
use Exception::Sink;

use Decor::Shared::Utils;
use Decor::Shared::Net::Protocols;

sub new
{
  my $class = shift;
  $class = ref( $class ) || $class;
  
  my %args = @_;
  
  my $self = {
             %args # FIXME: check and/or filter
             };
  bless $self, $class;

  $self->{ 'TIMEOUT' } = 60 if $self->{ 'TIMEOUT' } < 1;
  
  de_obj_add_debug_info( $self );
  $self->__init();
  return $self;
}

sub __init
{
  0;
}

sub __lock_self_keys
{
  my $self = shift;

  for my $key ( @_ )
    {
    next if exists $self->{ $key };
    $self->{ $key } = undef;
    }
  lock_ref_keys( $self );  
}

sub DESTROY
{
   my $self = shift;
   $self->disconnect();
}

##############################################################################

sub status
{
  my $self = shift;
  
  return $self->{ 'STATUS'  };
}

sub is_connected
{
  my $self = shift;
  
  return $self->{ 'SOCKET' } ? 1 : 0;
}

sub check_connected
{
  my $self = shift;
  
  boom "not connected" unless $self->is_connected();
}

sub connect
{
  my $self = shift;
  my $server_addr = shift; # ip:port

  my $socket = IO::Socket::INET->new( PeerAddr => $server_addr, Timeout => 2.0 );
  
  if( $socket )
    {
    $socket->autoflush( 1 );
    $self->{ 'SERVER_ADDR' } = $server_addr;
    $self->{ 'SOCKET'      } = $socket;
    }
  else
    {
    $self->reset();
    return undef;
    }  
  
  return 1;
}

sub disconnect
{
  my $self = shift;

  return 1 unless $self->is_connected();

  $self->{ 'SOCKET' }->close();
  $self->{ 'SOCKET' } = undef;

  $self->reset();

  return 1;
}

sub reset
{
  my $self = shift;

  %$self = ();

  return 1;
}

#-----------------------------------------------------------------------------

sub tx_msg
{
  my $self = shift;
  my $mi = shift;

  $self->check_connected();

  my $socket  = $self->{ 'SOCKET'  };
  my $timeout = $self->{ 'TIMEOUT' };
  
  $self->{ 'STATUS'  } = 'E_MSG';
  
  my $ptype = 'p'; # FIXME: config?
  
  my $mi_res = de_net_protocol_write_message( $socket, $ptype, $mi, $timeout );
  if( $mi_res == 0 )
    {
    $self->disconnect();
    return undef;
    }

  my $mo;
  ( $mo, $ptype ) = de_net_protocol_read_message( $socket, $timeout );
  if( ! $mo or ref( $mo ) ne 'HASH' )
    {
    $self->disconnect();
    return undef;
    }

  $self->{ 'STATUS'  } = $mo->{ 'XS' };
  
  return $mo;
}

#-----------------------------------------------------------------------------

sub begin_user_pass
{
  my $self = shift;
  
  my $user   = shift;
  my $pass   = shift;
  my $remote = shift;


  my $mop = $self->tx_msg( { 'XT' => 'P', 'USER' => $user } ) or return undef;

  my $user_salt  = $mop->{ 'USER_SALT'  };
  my $login_salt = $mop->{ 'LOGIN_SALT' };

  my %mi;

  $mi{ 'XT'     } = 'B';
  $mi{ 'USER'   } = $user;
  $mi{ 'PASS'   } = de_password_salt_hash( de_password_salt_hash( $pass, $user_salt ), $login_salt );
  $mi{ 'REMOTE' } = $remote;
  
  my $mo = $self->tx_msg( \%mi ) or return undef;
  # FIXME: TODO: if failed then disconnect?

  return $mo->{ 'SID' };
}

sub begin_user_session
{
  my $self = shift;
  
  my $user_sid = shift;
  my $remote   = shift;
 
  my %mi;

  $mi{ 'XT'       } = 'B';
  $mi{ 'USER_SID' } = $user_sid;
  $mi{ 'REMOTE'   } = $remote;
  
  my $mo = $self->tx_msg( \%mi ) or return undef;
  # FIXME: TODO: if failed then disconnect?

  return $mo->{ 'SID' };
}

sub end
{
  my $self = shift;
 
  my %mi;

  $mi{ 'XT'    } = 'E';
  
  my $mo = $self->tx_msg( \%mi ) or return undef;

  return 1;
}

#-----------------------------------------------------------------------------

sub describe
{
  my $self = shift;

  my $table  = uc shift;

  return $self->{ 'CACHE' }{ 'DESCRIBE' }{ $table }
      if $self->{ 'CACHE' }{ 'DESCRIBE' }{ $table };


  my %mi;

  $mi{ 'XT'    } = 'D';
  $mi{ 'TABLE' } = $table;

  my $mo = $self->tx_msg( \%mi ) or return undef;

  $self->{ 'CACHE' }{ 'DESCRIBE' }{ $table } = $mo->{ 'DES' };

  return $mo->{ 'DES' };
}

sub menu
{
  my $self = shift;

  return $self->{ 'CACHE' }{ 'MENU' }
      if $self->{ 'CACHE' }{ 'MENU' };


  my %mi;

  $mi{ 'XT'    } = 'M';

  my $mo = $self->tx_msg( \%mi ) or return undef;

  $self->{ 'CACHE' }{ 'MENU' } = $mo->{ 'MENU' };

  return $mo->{ 'MENU' };
}

#-----------------------------------------------------------------------------

sub select
{
  my $self = shift;

  my $table  = uc shift;
  my $fields = uc shift;
  my $opt    = shift;
  
  my $filter = $opt->{ 'FILTER' } || {};
  my $limit  = $opt->{ 'LIMIT'  };
  my $offset = $opt->{ 'OFFSET' };
  my $lock   = $opt->{ 'LOCK'   };
  # TODO: groupby, orderby

  my %mi;

  $mi{ 'XT' } = 'S';
  $mi{ 'TABLE'  } = $table;
  $mi{ 'FIELDS' } = $fields;
  $mi{ 'FILTER' } = $filter;
  $mi{ 'LIMIT'  } = $limit;
  $mi{ 'OFFSET' } = $offset;
  $mi{ 'LOCK'   } = $lock;

  my $mo = $self->tx_msg( \%mi ) or return undef;

  return $mo->{ 'SELECT_HANDLE' };
}

sub fetch
{
  my $self = shift;

  my $select_handle = shift;

  my %mi;

  $mi{ 'XT' } = 'F';
  $mi{ 'SELECT_HANDLE'  } = $select_handle;

  my $mo = $self->tx_msg( \%mi ) or return undef;

  return $mo->{ 'DATA' };
}

sub finish
{
  my $self = shift;

  my $select_handle = shift;

  my %mi;

  $mi{ 'XT' } = 'H';
  $mi{ 'SELECT_HANDLE'  } = $select_handle;

  my $mo = $self->tx_msg( \%mi ) or return undef;

  return 1;
}

#-----------------------------------------------------------------------------

sub insert
{
  my $self = shift;

  my $table  = uc shift;
  my $data   = shift;
  my $id     = shift;
  
  my %mi;

  $mi{ 'XT' } = 'I';
  $mi{ 'TABLE'  } = $table;
  $mi{ 'DATA'   } = $data;
  $mi{ 'ID'     } = $id;

  my $mo = $self->tx_msg( \%mi ) or return undef;

  return $mo->{ 'NEW_ID' };
}

sub update
{
  my $self = shift;

  my $self = shift;

  my $table  = uc shift;
  my $data   = shift;
  my $opt    = shift;
  
  my $filter = $opt->{ 'FILTER' } || {};
  my $id     = $opt->{ 'ID'     };
  my $lock   = $opt->{ 'LOCK'   };

  my %mi;

  $mi{ 'XT' } = 'S';
  $mi{ 'TABLE'  } = $table;
  $mi{ 'DATA'   } = $data;
  $mi{ 'FILTER' } = $filter;
  $mi{ 'ID'     } = $id;
  $mi{ 'LOCK'   } = $lock;

  my $mo = $self->tx_msg( \%mi ) or return undef;

  return 1;
}

sub delete
{
  my $self = shift;

  boom "sub_delete is not yet implemented";
}

#-----------------------------------------------------------------------------


##############################################################################
1;