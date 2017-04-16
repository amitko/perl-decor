##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Form;
use strict;

use Data::Tools;
use Exception::Sink;

use Decor::Core::Env;
use Decor::Core::Utils;
use Decor::Core::Describe;
use Decor::Shared::Utils;
use Decor::Shared::Types;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                de_form_gen_rec_data

                );

my %FORM_CACHE;

sub de_form_gen_rec_data
{
  my $form_name = shift;
  my $rec       = shift;
  my $data      = shift;
  my $opts      = shift;
  
  my $form_file = de_core_subtype_file_find( 'forms', 'txt', $form_name );

  my $form_text = file_load( $form_file );
  
  $form_text =~ s/\[(.*?)\]/__form_process_item( $1, $rec, $data, $opts )/gie;

  return $form_text;
}

sub __form_process_item
{
  my $item = uc shift;
  my $rec  = shift;
  my $data = shift;
  my $opts = shift;

  my $item_len = length $item;
  my $item_align = '<';
  
  $item =~ s/^\s*//;
  $item =~ s/\s*$//;
  
  my ( $name, $fmt ) = split /\s+/, $item, 2;

  my $item_dot = 8;
  ( $item_len, $item_dot ) = ( ( $1 || $item_len ), ( $3 || $4 ) ) if $fmt =~ /(\d+)(\.(\d+))?|\.(\d+)/;
  $item_align = $1 if $fmt =~ /([<=>])/;
  my ( $item_format, $item_format_name ) = ( 1, $2 ) if $fmt =~ /F(\(\s*([A-Z]+)\s*\))?/;

  my $tdes = describe_table( $rec->table() );
  my ( $bfdes, $lfdes ) = $tdes->resolve_path( $name );

  my $value;
  if( $lfdes )
    {
    $value = $rec->read( $name );
    if( $item_format )
      {
      my $ftype;
      if( ! $item_format_name )
        {
        $ftype = $lfdes->{ 'TYPE' };
        }
      else
        {
        $ftype = { NAME => $item_format_name, DOT => $item_dot };
        }  
      $value = type_format( $value, $ftype );
      }
    }
  elsif( exists $data->{ $name } )  
    {
    $value = $data->{ $name };
    $value = type_format( $value, { NAME => $item_format_name, DOT => $item_dot } ) if $item_format;
    }
  else
    {
    # TODO: warning: no such record field or data
    $value = '*?*';
    }

  if( $item_align eq '<' )
    {
    $value = str_pad( $value, $item_len );
    }
  elsif( $item_align eq '>' )
    {
    $value = str_pad( $value, -$item_len );
    }
  else
    {
    $value = str_pad_center( $value, $item_len );
    }  

  return $value;  
  
}


### EOF ######################################################################
1;
