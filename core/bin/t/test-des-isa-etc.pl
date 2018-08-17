#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;

use lib ( map { die "invalid DECOR_CORE_ROOT dir [$_]\n" unless -d; ( "$_/core/lib", "$_/shared/lib" ) } ( $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor' ) );

use Time::HR;

use Storable qw( dclone );
use Data::Lock qw( dlock dunlock );
use Data::Tools 1.09;

use Data::Dumper;
use Decor::Core::Env;
use Decor::Core::Config;
use Decor::Core::Profile;
use Decor::Core::Describe;
use Decor::Core::Log;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

my $opt_app_name;
my $opt_verbose;

our $help_text = <<END;
usage: $0 <options> application_name table fields
options:
    -v        -- verbose output
    -d        -- debug mode, can be used multiple times to rise debug level
    -r        -- log to STDERR
    -rr       -- log to both files and STDERR
    --        -- end of options
notes:
  * first argument is application name and it is mandatory!
  * options cannot be grouped: -rd is invalid, correct is: -r -d
END

our @args;
while( @ARGV )
  {
  $_ = shift;
  if( /^--+$/io )
    {
    push @args, @ARGV;
    last;
    }
  if( /^-d/ )
    {
    my $level = de_debug_inc();
    print "option: debug level raised, now is [$level] \n";
    next;
    }
    
  if( /^-v/ )
    {
    $opt_verbose = 1;
    next;
    }
  if( /-r(r)?/ )
    {
    $DE_LOG_TO_STDERR = 1;
    $DE_LOG_TO_FILES  = $1 ? 1 : 0;
    print "option: forwarding logs to STDERR\n";
    next;
    }
  if( /^(--?h(elp)?|help)$/io )
    {
    print $help_text;
    exit;
    }
  push @args, $_;
  }

my $opt_app_name = shift @args;

de_init( APP_NAME => $opt_app_name );

$_ = uc $_ for @args;

my $t = shift @args;

for my $t ( @args )
{
my $des = describe_table( $t );
if( ! $opt_verbose )
  {
  $des = dclone( $des );
  dunlock( $des );
  dunlock( $des->{ '@' } );
  my $self = $des->{ '@' };
  delete $des->{ '@' };
  $des->{ '@' }{ '@' } = $self;
  for my $cat ( keys %$des )
    {
    for my $entry ( keys %{ $des->{ $cat } } )
      {
      dunlock( $des->{ $cat }{ $entry } );
      print "des->{ $cat }{ $entry }\n";
      for my $attr ( keys %{ $des->{ $cat }{ $entry } } )
        {
        delete $des->{ $cat }{ $entry }{ $attr } if ! defined $des->{ $cat }{ $entry }{ $attr } or $attr =~ /^_/;
        }
      }
    }
  $des->{ '@' } = $des->{ '@' }{ '@' };
  delete $des->{ '@' }{ '@' };
  }
  print Dumper( $des );
  print "-" x 79 . "\n";
}
