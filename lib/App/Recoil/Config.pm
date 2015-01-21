##############################################################################
##
##  App::Recoil application machinery server
##  2014 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package App::Recoil::Config;
use strict;

use Data::Dumper;
use Data::Tools 1.07;
use Exception::Sink;
use App::Recoil::Env;
use App::Recoil::Utils;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                red_config_merge
                red_config_load
                red_config_load_file
                
                red_merge_config_file

                );

# FIXME catch nesting loops

##############################################################################

sub red_config_merge
{
  my $config = shift; # config hash ref
  my $name   = shift;
  my $dirs   = shift; # array reference
  
  red_check_name( $name  ) or boom "invalid NAME: [$name]";
  
  my @files = __red_resolve_config_files( $name, $dirs );
  
  for my $file ( @files )
    {
    red_merge_config_file( $config, $file, $dirs );
    }
  
  
  return $config; # FIXME return error?
}

sub red_config_load
{
  my $name  = lc shift;
  my $dirs  =    shift; # array reference

  my $config = {};
  red_config_merge( $config, $name, $dirs );
  
  return $config;
}

sub red_config_load_file
{
  my $fname = shift;

  my $config = {};
  red_merge_config_file( $config, $fname );
  
  return $config;
}

sub __red_resolve_config_files
{
  my $name  = lc shift;
  my $dirs  =    shift; # array reference

  return () unless $dirs and @$dirs > 0;

  my @files;
  
  push @files, glob_tree( "$_/$name.def" ) for @$dirs;

  return @files;
}

sub red_merge_config_file
{
  my $config = shift; # config hash ref
  my $fname  = shift;
  my $dirs   = shift; # array reference
  
  my $inf;
  open( $inf, $fname ) or return;

print STDERR "config: open: $fname\n";  

  my $sect_name = '@';
  $config->{ $sect_name } ||= {};
  
  my $ln; # line number
  while( my $line = <$inf> )
    {
    $ln++;
    my $origin = "$fname:$ln"; # localize $origin from the outer one

    chomp( $line );
    $line =~ s/^\s*//;
    $line =~ s/\s*$//;
    next unless $line =~ /\S/;
    next if $line =~ /^([#;]|\/\/)/;
print STDERR "        line: [$line]\n";  

    if( $line =~ /^=([a-zA-Z_0-9\:]+)\s*(.*?)\s*$/ )
      {
         $sect_name = uc $1;
      my $sect_opts =    $2; # fixme: upcase/locase?

print STDERR "       =sect: [$sect_name]\n";  
      
      $config->{ $sect_name } ||= {};
      %{ $config->{ $sect_name } } = ( %{ $config->{ $sect_name } }, %{ $config->{ '@' } } );
      
      if( $RED_DEBUG )
        {
        $config->{ $sect_name }{ 'DEBUG::ORIGIN' } ||= [];
        push @{ $config->{ $sect_name }{ 'DEBUG::ORIGIN' } }, $origin;
        }

      next;
      }

    if( $line =~ /^@(isa|include)\s*([a-zA-Z_0-9]+)\s*(.*?)\s*$/ )
      {
      my $name = $2;
      my $opts = $3; # fixme: upcase/locase?
  
      next unless $dirs and @$dirs > 0;
      
print STDERR "        isa:  [$name][$opts]\n";  

      my $isa = red_config_load( $name, $dirs );
      my @opts = split /[\s,]+/, uc $opts;

print STDERR "        isa:  DUMP: ".Dumper($isa)."\n";  
      
      for my $opt ( @opts )
        {
        boom "isa/include error: non existing key [$opt] in [$name]" unless exists $isa->{ $opt };
        $config->{ $opt } ||= {};
        %{ $config->{ $opt } } = ( %{ $config->{ $opt } }, %{ $isa->{ $opt } } );
        }
      
      next;
      }

    if( $line =~ /^([a-zA-Z_0-9\:]+)\s*(.*?)\s*$/ )
      {
      my $key   = uc $1;
      my $value =    $2;

      $value = 1 if $value eq '';

print STDERR "            key:  [$sect_name]:[$key]=[$value]\n";  

      $config->{ $sect_name }{ $key } = $value;
      
      next;
      }


    }
  close( $inf );
  
  return 1;
}

### EOF ######################################################################
1;
