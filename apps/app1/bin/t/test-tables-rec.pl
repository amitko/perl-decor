#!/usr/bin/perl
##############################################################################
##
##  Decor stagelication machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;
use lib ( $ENV{ 'DECOR_ROOT' } || die 'missing DECOR_ROOT env variable' ) . "/core/lib";

use Time::HR;

use Data::Dumper;
use Decor::Core::Env;
use Decor::Core::Config;
use Decor::Core::DSN;
use Decor::Core::Profile;
use Decor::Core::Describe;
use Decor::Core::DB::IO;
use Decor::Core::DB::Record;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

de_init( APP_NAME => 'app1' );
de_debug_set( 11 );

my $rio = new Decor::Core::DB::Record;

print Dumper( $rio );

$rio->create( 'test1' );

$rio->write( NAME => 'test name 115', SUMA => rand(), 'REF.NAME' => 'ref' . rand(), 'REF.CNT' => int(rand(100)) );
print Dumper( $rio );

$rio->save();

$rio->write( NAME => 'test name 116' );
print Dumper( $rio );

$rio->save();
print Dumper( $rio );

#dsn_commit();

my $dio = new Decor::Core::DB::IO;

$dio->select( 'test1', 'SUMA,.REF.CNT', '.REF.CNT > ?', { BIND => [ 60 ], LOCK => 1 } );
#$dio->select( 'test1', 'SUMA,REF.CNT' );
while( my $hr = $dio->fetch() )
  {
  print Dumper( $hr );
  }


print "\n" x 100;
  
$rio->select( 'test1', '.REF.CNT > ?', { BIND => [ 60 ], LOCK => 1 } );
while( $rio->next() )
  {
  print Dumper( $rio );
  }
