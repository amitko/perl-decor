package decor::actions::logout;
use strict;

use Data::Dumper;

sub main
{
  my $reo = shift;

  my $core = $reo->de_connect();                                                                                                
  $core->end();

  $reo->logout();
  return "<#logout_done>";
}

1;
