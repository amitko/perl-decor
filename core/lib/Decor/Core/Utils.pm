##############################################################################
##
##  Decor application machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Utils;
use strict;

use Exception::Sink;
use Decor::Core::Env;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                de_check_name
                de_check_name_boom
                de_reload_config

                de_obj_add_debug_info
                
                de_check_ref
                de_check_ref_hash
                de_check_ref_array
                );

##############################################################################

sub de_check_name
{
  my $name = shift;
  
  return $name =~ /^[a-zA-Z_0-9]+$/o ? 1 : 0;
}

sub de_check_name_boom
{
  my $name = shift;
  my $msg  = shift || "invalid NAME: [$name]";
  
  de_check_name( $name ) or boom $msg;
}

sub de_reload_config
{

die 'de_reload_config: is not implemented';

};

sub de_obj_add_debug_info
{
  return unless de_debug();
  my $obj = shift;

  my ( $pack, $file, $line, $subname ) = caller( 1 );
  $obj->{ 'DEBUG_ORIGIN' } = "$file:$line:$subname";
}

sub de_check_ref
{
  my $ref   = shift;
  my $class = shift;
  my $msg   = shift;
  
  my $got = ref( $ref );
  $msg ||= "expected reference of class [$class] got [$got]";
  boom $msg unless $got eq $class;
}

sub de_check_ref_hash  { return de_check_ref( $_[0], 'HASH',  $_[1] ); }
sub de_check_ref_array { return de_check_ref( $_[0], 'ARRAY', $_[1] ); }

### EOF ######################################################################
1;