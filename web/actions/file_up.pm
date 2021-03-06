##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::file_up;
use strict;
use Web::Reactor::HTML::Utils;
use Web::Reactor::HTML::Layout;
use Decor::Web::HTML::Utils;
use Decor::Web::View;
use Data::Dumper;

sub main
{
  my $reo = shift;

  return unless $reo->is_logged_in();

  my $text;

  my $table  = $reo->param( 'TABLE' );
  my $id     = $reo->param( 'ID'    );
  my $multi  = $reo->param( 'MULTI' );
  
  my $ui = $reo->get_user_input();
  my $si = $reo->get_safe_input();

  my $file_des    = $ui->{ 'FILE_DES' };

  my $lt_table = $reo->param( 'LINK_TO_TABLE' );
  my $lt_field = $reo->param( 'LINK_TO_FIELD' );
  my $lt_id    = $reo->param( 'LINK_TO_ID'    );

  my $rt_field = $reo->param( 'RETURN_DATA_TO' );

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );


  $multi = undef if $id > 0;
  $reo->html_content( 'multiple' => 'multiple' ) if $multi;

  my $text;

  my $file_upload_count = $ui->{ 'FILE_UPLOAD:FC' };


  if( $file_upload_count > 0 )
    {
    my $errors;
    
    my %ret_opt;

    for my $fc ( 0 .. $file_upload_count - 1 )
      {
      my $upload_fh = $ui->{ "FILE_UPLOAD:FH:$fc" };
      my $upload_fn = $ui->{ "FILE_UPLOAD:FN:$fc" };
      my $upload_fi = $ui->{ "FILE_UPLOAD:FI:$fc" };

      
      $upload_fn =~ s/^.*?\/([^\/]+)$/$1/;
      my $mime = $upload_fi->{ 'Content-Type' };
      my $new_id = $core->file_save_fh( $upload_fh, $table, $upload_fn, $id, { DES => $file_des, MIME => $mime } );
      
      my @fields = grep s/^F://, keys %$si;
      if( @fields > 0 )
        {
        my %data = map { $_ => $si->{ "F:$_" } } @fields;
        my $res = $core->update( $table, \%data, { FILTER => { _ID => $new_id } } );
        if( ! $res )
          {
          $errors .= "<p>$upload_fn: error updating file information!";
          }
        }
      
      if( ! $multi )
        {
        if( $new_id > 0 )
          {
          if( $lt_table and $lt_field and $lt_id > 0 )
            {
            my $res = $core->update( $lt_table, { $lt_field => $new_id }, { FILTER => { _ID => $lt_id } } );
            if( ! $res )
              {
              $errors .= "<p>$upload_fn: error updating file information!";
              }
            }
          $ret_opt{ "F:$rt_field" } = $new_id if $rt_field;
          }
        else
          {
          $text .= "<p>";
          $text .= "<#e_upload>";
          $text .= "<p>";
          $text .= "<#file_upload_form>";
          }  
        last;
        }
      }
    
    if( $errors )  
      {
      return $errors . "<p>" . de_html_alink_button( $reo, 'back', "[~Continue] &crarr;", "[~Operation done, continue...]"       );
      }
    else
      {  
      return $reo->forward_back( %ret_opt );
      }
    }
  else
    {
    $text .= "<#file_upload_form>";
    }  

  return $text;
}

1;
