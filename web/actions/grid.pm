package decor::actions::grid;
use strict;
use Data::Dumper;

sub main
{
  my $reo = shift;

  return unless $reo->is_logged_in();
  
  my $table = $reo->param( 'TABLE' );

  my $core = $reo->de_connect();
  my $des  = $core->describe( $table );

  print STDERR Dumper( $des );

  my $text = "grid here $table <xmp>" . Dumper( $des->get_fields_list_by_oper( 'READ' ) ) . "</xmp>";

  my $offset =  0;
  my $limit  = 15;
  
  my @fields = @{ $des->get_fields_list_by_oper( 'READ' ) };
  my $fields = join ',', @fields;
  
  my $select = $core->select( $table, $fields, { OFFSET => $offset, LIMIT => $limit, ORDER_BY => '_ID DESC' } );

  my $text = "select core <xmp>" . Dumper( $select ) . "</xmp>";
  
  $text .= "<table cellspacing=0 cellpadding=0 width=100% border=1>";
  $text .= "<tr>";
  for my $f ( @fields )
    {
    $text .= "<td class=view-head>$f</td>";
    }
  $text .= "</tr>";
  while( my $row_data = $core->fetch( $select ) )
    {
    $text .= "<tr>";
    for my $f ( @fields )
      {
      my $data = $row_data->{ $f };
      $text .= "<td class=view-head>$data</td>";
      }
    $text .= "</tr>";
    }
  $text .= "</table>";

=pod
  $text .= "<table cellspacing=0 cellpadding=0 width=100%><tr><td align=center><table class=menu cellspacing=0 cellpadding=0 width=80%><tr>";
  for my $key ( keys %$menu )
    {
    next if $key eq '@';
    my $item = $menu->{ $key };
    next unless $item->{ 'GRANT' }{ 'ACCESS' };
    next if     $item->{ 'DENY'  }{ 'ACCESS' };

    my $label = $item->{ 'LABEL' } || $key;
    my $type  = $item->{ 'TYPE'  };
    
    my $link;
    if( $type eq 'SUBMENU' )
      {
      $link = "<a class=menu reactor_new_href=?action=menu&menu=$key>$label</a>";
      }
    elsif( $type eq 'GRID' )
      {
      my $table  = $item->{ 'TABLE'  };
      $link = "<a class=menu reactor_new_href=?action=grid&table=$table>$label</a>";
      }
    elsif( $type eq 'INSERT' )
      {
      my $table  = $item->{ 'TABLE'  };
      $link = "<a class=menu reactor_new_href=?action=edit&table=$table&id=-1>$label</a>";
      }
    else
      {
      $reo->log( "error: menu: invalid item [$key] type [$type]" );
      next;
      }  

    $text .= "<tr><td class=menu>$link</td></tr>";
    }
  $text .= "</table></td></tr></table>";
=cut  
  return $text;
}

1;