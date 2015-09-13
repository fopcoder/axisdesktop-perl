## @file
# Implementation of Gears::ArticlePage

## @addtogroup Article
# @{
## @class
# Manage of articles output

package Gears::ArticlePage;

## }@

use strict;
use base qw(Gears);
use CGI::SSI_M;
use HTML::Template::Pro;
use HellFire::Article::ItemDAO;
use HellFire::Article::CategoryDAO;

sub new {
	my $class = shift;
	my $self;

	$self->{_request} = shift;
	$self->{_dbh}     = $self->{_request}->dbh;
	$self->{_guard}   = $self->{_request}->guard;

	bless $self, $class;

	return $self;
}


sub expand_menu_action	{
	my $self = shift;
	
	my $params = $self->eval_params();
	my $C = new HellFire::Article::CategoryDAO( $self->dbh, $self->guard );
	$C->load( $params->{parent_id} );
	my $arr = $C->get_all_siblings( $params->{parent_id}, { lang_id => 1 } );
	my $re1 = $self->url_to_category( $params->{parent_id}, [ split( /\//, $ENV{REQUEST_URI} ) ] );
	
	my( $obj, $obj2 );
	if( defined $$re1[-2] ) {
		$obj  = $$re1[-1]->get_id();
		$obj2 = $$re1[-2]->get_id();
	}
	if( defined $$re1[-1] ) {
		$obj = $$re1[-1]->get_id();
	}
	undef $re1;

	my @_re;
	foreach my $r ( @$arr ) {
		my @_ce;
		if( $obj2 == $r->get_id() || $obj == $r->get_id() ) {

			#my $S =  new HellFire::Article::CategoryDAO( $self->dbh, $G );
			my $ar2 = $C->get_all_siblings( $r->get_id(), { lang_id => 1 } );

			foreach my $c ( @$ar2 ) {
				my $this;
				$this = 1 if( $c->get_id() == $obj2 || $c->get_id() == $obj );
				my $href = ( $params->{href} ) . '/' . $r->get_name() . '/' . $c->get_name();
				push @_ce, { alias => $c->get_alias( $self->guard->get_lang_id() ) || $c->get_name(), href => $href, this => $this };
			}
		}
		my $this;
		$this = 1 if( $r->get_id() == $obj );

		my $href;
		if( $params->{href} ) {
			$href = ( $params->{href} ) . '/' . $r->get_name();
		}
		else {
			$href = '/' . $C->get_name() . '/' . $r->get_name();
		}

		push @_re, { rows => \@_ce, alias => $r->get_alias( $self->guard->get_lang_id() ) || $r->get_name(), href => $href, this => $this, content => \@_ce };
	}
	$params->{ action } = 'expand_menu';	
	$params->{ obj } = $C;	
	$params->{ rows } = \@_re;
	
	$self->output( $params );
	
}

sub subcategories_menu_action  {
    my $self = shift;

	my $params = $self->eval_params();
	my $C = new HellFire::Article::CategoryDAO( $self->dbh, $self->guard );
	my $re1 = $self->url_to_category( $params->{parent_id}, [ split( /\//, $ENV{REQUEST_URI} ) ] );
	my $arr = $C->get_all_siblings( $$re1[0]->get_id||$params->{parent_id}, { lang_id => 1 } );
	$C->load( $$re1[0]->get_id || $params->{parent_id} );


	my @_re;
	foreach my $r ( @$arr ) {
			my @f;
			my $href;
			if( defined $params->{href} ) {
					$href = ( $params->{href} ) . '/' . $r->get_name();
			}
			else {
					$href = '/' . $C->get_name() . '/' . $r->get_name();
			}

			my $sel = 0;
			if( $$re1[1] )  {
				if( $$re1[1]->get_id == $r->get_id() )  {
					$sel = 1;
				}
			}
			push @_re, {
				name => $r->get_name(),
				alias => $r->get_alias( $self->guard->get_lang_id() ),
				id => $r->get_id(),
				href => $href,
				selected => $sel
			};
	}

	$params->{ action } = 'subcategories_menu';
	$params->{ obj } = $C;
	$params->{ rows } = \@_re;

	$self->output( $params );
}


=head
parent_id => 49,
limit => 10,
href => '/fff'
with_name => 1,
with_alias => 1
with_inserted
with_updated
with_ordering
with_hidden
with_deleted
with_index_file_groups
with_index_subfolders => 5 (level down)
with_index_child_items
with_index_count_subfolders_items
=cut

sub index_action {
	my $self = shift;

	my $params = $self->eval_params();
	my $AI = new HellFire::Article::ItemDAO( $self->dbh, $self->guard );
	my $AC = new HellFire::Article::CategoryDAO( $self->dbh, $self->guard );
	$AC->load( $params->{parent_id} );

	my $url = $self->param_to_category( $params->{parent_id} );
	if( $url ) {
		$self->set_crumbs( { url => $url } );
		
		my $output_params = { action => 'index' };
		$params->{href} ||= $self->request->url->path();
		$params->{href} .= '/' unless( $params->{href} =~ /\/$/);
		$params->{href} .= join('/',@{$self->request->url->param});
		$params->{with_file_groups} = $params->{with_index_file_groups};
		$params->{offset} = $self->request->page() * $params->{limit};
		$params->{page} = $self->request->page();
		
		if( defined $$url[-1] ) {
			if( $params->{with_subcontent} )	{
				my $cid = $self->get_all_visible_children_id( $$url[-1] );
				$params->{category_id} = join( ',', @$cid, $$url[-1]->get_id() );
			}
			else	{
				$params->{category_id} = $$url[-1]->get_id();	
			}
			
			$output_params->{ obj } = $$url[-1];
		}
		else	{
			$output_params->{ obj } = $AC;			
		}
		
		if( $params->{with_index_subfolders} )	{
			$output_params->{ subfolders } = $output_params->{ obj }->get_subfolders( $params );
		}
		
		$output_params->{ rows } = $AI->get_grid( $params );
		if( scalar @{$output_params->{ rows }} == 1 )	{
			$self->item_action( { id => $$output_params{ rows }[0]->{id} } );
			return;
		}
		$output_params->{ paging } = $self->paging( $params );
		
		$self->output( $output_params );
	}
	else	{
		$self->output();
	}

}

sub item_action {
	my $self = shift;
	my $in = shift;

	my $params = $self->eval_params();
	my $AI = new HellFire::Article::ItemDAO( $self->dbh, $self->guard );
	my $url = $self->param_to_category( $params->{parent_id} );
	
	if( $url ) {
		if( defined $$url[-1] ) {
			$params->{category_id} = $$url[-1]->get_id();
		}
		$AI->set_parent_id( $params->{category_id}||$params->{parent_id} );
		if( $AI->load( $AI->find( $self->request->url->item_name() )||$in->{id}, { no_clean => 1, lang_id => $self->guard->get_lang_id() } ) ) {
			require HellFire::File::ItemDAO;
			my $ddd;
			if( $params->{with_item_file_groups} ) {
				$params->{with_file_groups} = $params->{with_item_file_groups};
				my $File = new HellFire::File::ItemDAO( $self->dbh, $self->guard );
				$ddd = $File->get_files_by_group( {
						obj => 'HellFire::Article::ItemDAO',
						id => $AI->get_id },
					$params
				);
            }

require HellFire::File::ItemDAO;
my $ddd;
                if( $params->{with_item_file_groups} ) {
                        $params->{with_file_groups} = $params->{with_item_file_groups};
my $File = new HellFire::File::ItemDAO( $self->dbh, $self->guard );
                        $ddd = $File->get_files_by_group( {
                                obj => 'HellFire::Article::ItemDAO',
                                id => $AI->get_id },
                                $params  );
                }

				my $rows;
			
			if( $params->{crosslink} )	{
				my $query = '
				(
					SELECT ai.id, ai.parent_id, aa.alias, ai.name, concat(ai.name,".html") AS href
					FROM article_items ai
					JOIN article_item_aliases aa ON ai.id = aa.parent_id AND aa.lang_id = 1
					WHERE ai.parent_id = ? AND ai.id < ? AND FIND_IN_SET( ai.flags, "HIDDEN" ) = 0
					ORDER  BY ai.id DESC
					LIMIT ?
				)
				UNION
				(
					SELECT ai.id, ai.parent_id, aa.alias, ai.name, concat(ai.name,".html") AS href
					FROM article_items ai
					JOIN article_item_aliases aa ON ai.id = aa.parent_id AND aa.lang_id = 1
					WHERE ai.parent_id = ? AND ai.id <> ? AND FIND_IN_SET( ai.flags, "HIDDEN" ) = 0
					ORDER  BY ai.id DESC
					LIMIT ?
				)
				LIMIT ?
				';
				my $dbh = $self->dbh;
				$rows = $dbh->selectall_arrayref( $query, { Slice => {} },
					$params->{category_id}||$params->{parent_id}, $AI->get_id, $params->{crosslink},
					$params->{category_id}||$params->{parent_id}, $AI->get_id, $params->{crosslink},
					$params->{crosslink}
				);
			}
				

                        $params = $AI->to_template();
						$params->{crosslink} = $rows;
                        $params->{file_groups} = $ddd;

			$params->{file_groups} = $ddd;
			unless( $self->request->level() )	{
				$self->request->response->header('Last-Modified', $AI->get_last_modified() );
			}
		}
		
		$self->set_crumbs( { url => $url, item => $AI }  );
		
		$self->output(
			{
				action => 'item',
				obj    => $AI,
				%$params
			}
		);
	}
	else	{
		$self->output();
	}
}

sub output {
	my $self   = shift;
	my $params = shift;

	unless( $params->{obj} && $params->{obj}->get_name() ) {
		$self->request->response->header( 'Status', '404 Not Found' );
		return;
	}

	if( $params->{action} ) {
		my $I = new HellFire::Site::ItemDAO( $self->dbh, $self->guard );
		$I->set_parent_id( $self->request->url->site_object->get_id() );
		if( $I->load( $I->find( $params->{action} . '.ax' ), { no_clean => 1, lang_id => $self->guard->get_lang_id() } ) ) {
			my $out;
			my $ff;
			my $SSI = new CGI::SSI_M( request => $self->request );

			my $prefix = $self->request->domain->get_id();
			$prefix .= '/t';

			my $prefixc = $self->request->domain->get_id();
			$prefixc .= '/c/' . $I->get_parent_id();

			if( $I->get_content( $self->guard->get_lang_id() ) ) {
				my $file = $self->guard->ini->template_dir . "/$prefixc/" . $I->get_content( $self->guard->get_lang_id() );
				if( -s $file && open( FILE, $file ) ) {
					$ff = join( '', <FILE> );
					close FILE;

					my $tpl = HTML::Template::Pro->new(
						'die_on_bad_params' => 0,
						'loop_context_vars' => 1,
						'scalarref'         => \$ff,
					);

					$tpl->param( $params );
					$ff = $tpl->output();
				}
			}

			my $query = 'select * from site_templates t, site_template_content c where c.parent_id = t.id and lang_id = ? and t.id = ?';
			my $TT = $self->dbh->selectrow_hashref( $query, undef, $self->guard->get_lang_id(), $I->get_template_id() );

			if( $TT->{content} ) {
				my $file = $self->guard->ini->template_dir . "/$prefix/" . $TT->{content};
				if( -s $file && open( FILE, $file ) ) {
					$out = join( '', <FILE> );
					close FILE;

					my $tpl = HTML::Template::Pro->new(
						'die_on_bad_params' => 0,
						'loop_context_vars' => 1,
						'scalarref'         => \$out,
					);
					$tpl->param( __content__ => $ff );
					$out = $tpl->output();
				}
				else {
					$out = $ff;
				}
			}
			else {
				$out = $ff;
			}

			$self->set_metadata( $params->{obj}, $self->request->url->site_object );
			$self->request->response->content( $SSI->process( $out ) );
		}
		else {
			warn '== article_page -> ' . $params->{action} . '_action : ' . $params->{action} . '.ax not found';
		}
	}
	else {
		warn '== article_page -> output : no action defined';
	}
}

sub param_to_category {
	my $self   = shift;
	my $cat_id = shift;

	my @ret;

	foreach ( @{ $self->request->url->param() } ) {
		next unless $_;
		my $iname = $self->request->url->item_name();
		last if( $_ =~ /^$iname\.\w+$/ );
		
		my $S = new HellFire::Article::CategoryDAO( $self->dbh, $self->guard );
		$S->set_parent_id( $cat_id );
		if( $S->load( $S->find( $_ ), { lang_id => 1, no_clean => 1 } ) ) {
			push @ret, $S;
			$cat_id = $S->get_id();
		}
		else {
			return undef;
		}
	}

	return \@ret;
}

sub set_crumbs {
	my $self = shift;
	my $params  = shift;

	unless( $self->request->level() )	{
		my $ppp = $self->request->url->path();
		$ppp =~ s/\/$//;
		foreach ( @{ $params->{url} } ) {
			$ppp .= '/' . $_->get_name();
			$self->request->response->crumbs(
				{
					name  => $_->get_name(),
					alias => $_->get_alias( $self->guard->get_lang_id ) || $_->get_name(),
					href  => $ppp
				}
			);
		}
		
		if( $params->{item} )	{
			$self->request->response->crumbs(
				{
					name  => $params->{item}->get_name(),
					alias => $params->{item}->get_alias( $self->guard->get_lang_id ) || $params->{item}->get_name(),
					href  => $ppp .'/'.$params->{item}->get_name().'.'.$self->request->url->extension()
				}
			);
		}
	}
}

sub paging	{
	my $self = shift;
	my $params = shift;
	
	#my $paging = {
	#	paging => [],
	#	paging_first => undef,
	#	paging_last => undef,
	#	paging_prev => undef,
	#	paging_next => undef
	#};
	my @res;
	if( $params->{count_all} > $params->{limit} && $params->{limit} > 0  )	{
		
		my $p = int($params->{count_all} / $params->{limit} + 0.9999999 );
		$params->{href} =~ s/\/$//;
		
		for( my $i = 0; $i < $p; $i++ )	{
			push @res, {
				alias => $i+1,
				href =>  $i ? $params->{href}.'/:p='.$i : $params->{href},
				active => ( $params->{page} == $i ) ? 1 : 0,
				page => 1
			};
		}
	}
	
	return \@res;
}


sub url_to_category {
	my $self   = shift;
	my $cat_id = shift;
	my $url    = shift;

	my @ret;

	#my $S = new HellFire::Article::CategoryDAO( $self->dbh, $G );
	#$S->load( $cat_id, { lang_id => 1 } );
	#push @ret, $S;
	foreach ( @$url ) {
		next unless $_;
		my $S = new HellFire::Article::CategoryDAO( $self->dbh, $self->guard );
		$S->set_parent_id( $cat_id );
		if( $S->load( $S->find( $_ ), { lang_id => 1 } ) ) {
			push @ret, $S;
			$cat_id = $S->get_id();
		}
	}

	return \@ret;
}

sub get_all_visible_children_id {
	my $self = shift;
	my $C = shift;

	my $query = 'SELECT id, index_right-index_left c
					FROM article_categories
					WHERE index_left > ? AND index_right < ? AND find_in_set("DELETED",flags) = 0
						AND find_in_set("HIDDEN",flags) = 0
					ORDER BY c';
	my $sth   = $self->dbh->prepare( $query );
	$sth->execute( $C->get_index_left(), $C->get_index_right() );
	my @arr;

	while ( my @a = $sth->fetchrow_array() ) {
		push @arr, $a[0];
	}

	return \@arr;
}



#sub run {
#	my $self = shift;
#	my $G    = $self->request->guard;
#	my $O    = $self->request->url->site_object;
#	my $url  = $self->request->url->param;
#	my $q    = $self->request->q;
#
#	my $order_by  = $self->_order_by();
#    my $direction = $self->_direction();
#	my $start = $q->param( 'start' ) || 0;
#	my $limit = $q->param( 'limit' ) || $self->config->{ $G->get_path() }->{limit} || 50;
#	my $rowsc = 0;
#
#
#	my $eee;
#	my $is_page   = 0;
#	my $page_type = 'index';
#	my $pid       = $self->config->{ $G->get_path() }->{category_id};
#
#	$pid = $self->request->get_value( 'category_id' ) if( $self->request->get_value( 'category_id' ) );
#
#	my $re = $self->url_to_category( $G, $pid, $url );
#
#
#	if( scalar @$re ) {
#		$pid = $$re[-1]->get_id();
#		if( $$re[-1]->get_children() ) {
#			$page_type = 'level';
#		}
#		else {
#			$page_type = 'index';
#		}
#	}
#	undef $re;
#
#	$pid = $self->request->get_value( 'parent_id' ) if( $self->request->get_value( 'parent_id' ) );
#
#	if( $self->config->{ $self->guard->get_path() }->{load_default_page} && !( $$url[-1] =~ /html$/ ) ) {
#
#=head
#			my $query = ' ( select name from article_items where find_in_set("DEFAULT",flags) > 0 and parent_id = ? limit 1 )
#					union
#					( select name from article_items where parent_id = ? limit 1 )
#					limit 1';
#			my $name = $self->dbh->selectrow_array( $query, undef, $pid, $pid );
#=cut
#
#		my $query = 'select name from article_items where find_in_set("DEFAULT",flags) > 0 and parent_id = ? limit 1';
#		my $name = $self->dbh->selectrow_array( $query, undef, $pid );
#
#		if( $name ) {
#			push @$url, $name . '.html';
#		}
#	}
#	elsif( $self->config->{ $self->guard->get_path() }->{load_one_page} && !( $$url[-1] =~ /html$/ ) ) {
#		my $query = 'select name, count(*) cc  from article_items where parent_id = ? group by parent_id having cc = 1';
#		my $name = $self->dbh->selectrow_array( $query, undef, $pid );
#		if( $name ) {
#			push @$url, $name . '.html';
#		}
#	}
#
#	if( $$url[-1] =~ /html$/ ) {
#		$is_page = $$url[-1];
#		$is_page =~ s/\.html//;
#		@$url = splice( @$url, 0, -1 );
#		$page_type = 'item';
#	}
#
#	if( $$url[-2] eq '_p' ) {
#		$start = $$url[-1] || 0;
#		pop @$url;
#		pop @$url;
#	}
#
#	my @menus;
#	my @header;
#	my $item;
#	my @fili;
#	my @files;
#	my @files_by_group;
#	my @cmt;
#	my @filter;
#	my @filter_selected;
#
#	my @filter_id;
#	my %ITEMS;
#
#	my %we;
#	foreach ( sort $q->param() ) {
#		if( ( $_ =~ /f(\d+)min/ && length( $q->param( $_ ) ) ) ||
#            ( $_ =~ /f(\d+)max/ && length( $q->param( $_ ) ) ) ||
#            ( $_ =~ /f(\d+)like/ && length( $q->param( $_ ) ) ) ||
#            ( $_ =~ /^f(\d+)$/ && length( $q->param( $_ ) ) ) ||
#            ( $_ =~ /(alias)_(\d+)/ && length( $q->param( "alias_$2" ) ) )
#        )   {
#			my $fid = $1;
#            next if $we{$fid};
#            my( $sth, $query );
#
#            if( $fid =~ /\d+/ ) {
#                my $F = new HellFire::Article::FieldDAO( $self->dbh, $G );
#                $F->load( $fid );
#
#				if( length( $q->param( "f$fid\min" ) ) && length( $q->param( "f$fid\max" ) ) ) {
#					$query = 'select i.id from article_items i inner join article_values_' . ( $F->get_type() ) . ' v on v.item_id = i.id where v.parent_id = ? and i.parent_id = ? and value between ? and ?';
#					$sth = $self->dbh->prepare( $query );
#					$sth->execute( $fid, $pid, $q->param( "f$fid\min" ), $q->param( "f$fid\max" ) );
#				}
#				elsif( length( $q->param( "f$fid\min" ) ) && !length( $q->param( "f$fid\max" ) ) ) {
#					$query = 'select i.id from article_items i inner join article_values_' . ( $F->get_type() ) . ' v on v.item_id = i.id where v.parent_id = ? and i.parent_id = ? and value >= ? ';
#					$sth = $self->dbh->prepare( $query );
#					$sth->execute( $fid, $pid, $q->param( "f$fid\min" ) );
#				}
#				elsif( !length( $q->param( "f$fid\min" ) ) && length( $q->param( "f$fid\max" ) ) ) {
#					$query = 'select i.id from article_items i inner join article_values_' . ( $F->get_type() ) . ' v on v.item_id = i.id where v.parent_id = ? and i.parent_id = ? and value <= ? ';
#					$sth = $self->dbh->prepare( $query );
#					$sth->execute( $fid, $pid, $q->param( "f$fid\max" ) );
#				}
#				elsif( $q->param( 'f'.$fid.'like' ) ) {
#					$query = 'select i.id from article_items i inner join article_values_' . ( $F->get_type() ) . ' v on v.item_id = i.id where v.parent_id = ? and i.parent_id = ? and value like ? ';
#					$sth = $self->dbh->prepare( $query );
#					$sth->execute( $fid, $pid, '%'.$q->param( 'f'.$fid.'like' ).'%' );
#				}
#				elsif( $q->param( "f$fid" ) ) {
#					$query = 'select i.id from article_items i inner join article_values_' . ( $F->get_type() ) . ' v on v.item_id = i.id where v.parent_id = ? and i.parent_id = ? and value = ? ';
#					$sth = $self->dbh->prepare( $query );
#					$sth->execute( $fid, $pid, $q->param( "f$fid" ) );
#				}
#			}
#			else    {
#                if( $fid eq 'alias' && $q->param( 'alias_'.$G->get_lang_id() ) ) {
#                    $query = 'select i.id from article_items i inner join article_item_aliases a on a.parent_id = i.id and a.lang_id = ? where a.alias = ?';
#                    $sth = $self->dbh->prepare( $query );
#                    $sth->execute( $fid, $pid, $G->get_lang_id(), $q->param( 'alias_'.$G->get_lang_id() ),  );
#                }
#            }
#
#			while ( my $h = $sth->fetchrow_hashref ) {
#				push @{ $ITEMS{$fid} }, $h->{id};
#			}
#
#			$we{$1} = 1;
#		}
#	}
#
#	if( $self->request->url->get_filter || 1 ) {
#		@filter_id = split( /_/, $self->request->url->get_filter );
#
#		my @_sel_id;
#		foreach ( @filter_id ) {
#
#			#my $I = new HellFire::Article::ItemDAO( $self->dbh, $G );
#			#$I->load( $_, { lang_id => 1 } );
#			#push @_sel_id, $I;
#			$_ =~ /^(\d+):(\d+)/;
#			my $_t = $1;
#			my $_i = $2;
#			my $tn = $self->dbh->selectrow_array( 'select name from configuration where id = ?', undef, $_t );
#			$tn =~ s/(\w)/\u$1/;
#			eval( 'require HellFire::' . $tn . '::ItemDAO' );
#			my $I;
#			eval( '$I = new HellFire::' . $tn . '::ItemDAO( $self->dbh, $G )' );
#			$I->load( $_i, { lang_id => 1 } );
#			push @_sel_id, $I;
#		}
#
#		#my $url = $ENV{REQUEST_URI};
#		#$url =~ s/\/+_p.*//;
#		#$url =~ s/\/filter.*//;
#		#$url =~ s/(\/)+$//;
#		my $url = $self->request->url->get_location;
#
#		my $F = new HellFire::Article::FieldDAO( $self->dbh, $G );
#		$F->set_parent_id( $pid );
#		my $ff = $F->get_fields(
#			{
#				lang_id        => 1,
#				with_fields    => $self->config->{ $self->guard->get_path() }->{with_filter_fields},
#				without_fields => $self->config->{ $self->guard->get_path() }->{without_filter_fields}
#			}
#		);
#		my @_fid;
#
#		foreach my $rf ( @$ff ) {
#			my $test = 0;
#			my @values;
#
#			foreach my $k ( @_sel_id ) {
#				if( $k->get_parent_id() == $rf->get_source_id ) {
#					my $query = 'select i.id from article_items i inner join article_values_reference v on v.item_id = i.id where v.parent_id = ? and i.parent_id = ? and value = ? ';
#					my $sth   = $self->dbh->prepare( $query );
#					$sth->execute( $rf->get_id(), $pid, $k->get_id() );
#
#					while ( my $h = $sth->fetchrow_hashref ) {
#						push @{ $ITEMS{ $rf->get_id } }, $h->{id};
#					}
#
#					$test = 1;
#					my $href = $url;
#					if( scalar @filter_id > 1 ) {
#						$href .= '/filter/';
#						$href .= join( '_', grep { $_ ne $rf->get_source_group_id . ':' . $k->get_id() } sort @filter_id );
#					}
#
#					push @values,
#					  {
#						alias => $k->get_alias( $G->get_lang_id() ) || $k->get_name,
#						href => $href
#					  };
#				}
#			}
#
#			my %we;
#			foreach ( $q->param() ) {
#				if( ( $_ =~ /f(\d+)min/ || $_ =~ /f(\d+)max/ ) && $rf->get_id() == $1 ) {
#					next if $we{$1};
#
#					$test = 1;
#					my $href = '';
#
#					#push @values, { alias => $q->param("f$1\min")||'', href => $href };
#					#push @values, { alias => 'aaa', href => $href };
#					push @values, { alias => $q->param( "f$1\min" ), href => $href };
#					push @values, { alias => $q->param( "f$1\max" ), href => $href };
#
#					#		{ alias => $q->param("f$1\max")||'', href => $href } );
#					$we{$1} = 1;
#				}
#			}
#
#			if( $test ) {
#				push @filter_selected, { id => $rf->get_id(), alias => $rf->get_alias( $G->get_lang_id() ) || $rf->get_name(), values => \@values };
#			}
#		}
#	}
#
#	my $ret_f;
#	if( $page_type eq 'index' ) {
#		$ret_f = $self->get_filter(
#			{
#				filter    => \@filter,
#				filter_id => \@filter_id,
#				items     => \%ITEMS,
#				pid       => $pid
#			}
#		);
#	}
#
#	if( $$url[-2] eq 'menu' ) {
#
#		#my $category_id =
#
#		elsif( $$url[-1] eq '2level' ) {
#			my $C = new HellFire::Article::CategoryDAO( $self->dbh, $G );
#			my $arr = $C->get_all_siblings( $pid );
#			undef $C;
#
#			my @_re;
#			foreach my $r ( @$arr ) {
#				my $S = new HellFire::Article::CategoryDAO( $self->dbh, $G );
#				my $ar2 = $S->get_all_siblings( $r->get_id() );
#
#				my @_ce;
#				foreach my $c ( @$ar2 ) {
#					push @_ce, { name => $c->get_name(), parent_name => $r->get_name(), alias => $c->get_alias( $G->get_lang_id() ), id => $c->get_id(), href => '/' . $r->get_name() . '/' . $c->get_name() };
#				}
#				push @_re, { cols => \@_ce, name => $r->get_name(), alias => $r->get_alias( $G->get_lang_id() ), id => $r->get_id(), href => '/' . $r->get_name() };
#			}
#			push @menus, { rows => \@_re };
#		}
#		elsif( $$url[-1] eq 'children' ) {
#			my $re1 = $self->url_to_category( $G, $pid, [ split( /\//, $ENV{REQUEST_URI} ) ] );
#			my $C = new HellFire::Article::CategoryDAO( $self->dbh, $G );
#			$C->load( $self->config->{ $G->get_path() }->{category_id}, { lang_id => 1 } );
#			my $arr = $C->get_all_siblings( $self->config->{ $G->get_path() }->{category_id}, { lang_id => 1 } );
#
#			my @_re;
#			foreach my $r ( @$arr ) {
#				my @f;
#
#=head
#				$self->get_filter(	{
#						filter => \@f,
#						filter_id => [],
#						items => {},
#						pid => $r->get_id(),
#						append_url => '/'.$r->get_name()
#					}
#				);
#=cut
#
#				my $href;
#				if( $self->config->{ $G->get_path() }->{href} ) {
#					$href = ( $self->config->{ $G->get_path() }->{href} ) . '/' . $r->get_name();
#				}
#				else {
#					$href = '/' . $C->get_name() . '/' . $r->get_name();
#				}
#				push @_re, { name => $r->get_name(), alias => $r->get_alias( $G->get_lang_id() ), id => $r->get_id(), href => $href, filter => \@f };
#
#			}
#			push @menus, { rows => \@_re };
#		}
#		elsif( $$url[-1] eq 'children_with_content' ) {
#			my $re1 = $self->url_to_category( $G, $pid, [ split( /\//, $ENV{REQUEST_URI} ) ] );
#
#			my $C = new HellFire::Article::CategoryDAO( $self->dbh, $G );
#			$C->load( $self->config->{ $G->get_path() }->{category_id}, { lang_id => 1 } );
#			my $arr = $C->get_all_siblings( $self->config->{ $G->get_path() }->{category_id}, { lang_id => 1 } );
#
#			my @_re;
#			foreach my $r ( @$arr ) {
#				my @f;
#
#=head
#				$self->get_filter(	{
#						filter => \@f,
#						filter_id => [],
#						items => {},
#						pid => $r->get_id(),
#						append_url => '/'.$r->get_name()
#					}
#				);
#=cut
#
#				my $cont;
#				if( scalar @$re1 && $$re1[-1]->get_id() == $r->get_id() ) {
#					$cont = $C->get_grid(
#						{
#							parent_id       => $r->get_id(),
#							order_id        => $order_by,
#							order_direction => $direction,
#							offset          => $self->request->url->get_page() * $limit,
#							limit           => $limit,
#						}
#					);
#
#					foreach ( @$cont ) {
#						$_->{href} = ( $self->config->{ $G->get_path() }->{href} ) . '/' . $$re1[-1]->get_name() . '/' . $_->{name} . '.html';
#					}
#				}
#
#				my $href;
#				if( $self->config->{ $G->get_path() }->{href} ) {
#					$href = ( $self->config->{ $G->get_path() }->{href} ) . '/' . $r->get_name();
#				}
#				else {
#					$href = '/' . $C->get_name() . '/' . $r->get_name();
#				}
#
#				push @_re, { name => $r->get_name(), alias => $r->get_alias( $G->get_lang_id() ), id => $r->get_id(), href => $href, filter => \@f, content => $cont };
#
#			}
#			push @menus, { rows => \@_re };
#		}
#		elsif( $$url[-1] eq 'all_with_content' ) {
#			my $re1 = $self->url_to_category( $G, $pid, [ split( /\//, $ENV{REQUEST_URI} ) ] );
#
#			my $C = new HellFire::Article::CategoryDAO( $self->dbh, $G );
#			$C->load( $pid, { lang_id => 1 } );
#			my $arr = $C->get_all_siblings( $pid, { lang_id => 1 } );
#
#
#
#			my @_re;
#			foreach my $r ( @$arr ) {
#				my $F = new HellFire::Article::FieldDAO( $self->dbh, $G );
#				$F->set_parent_id($r->get_id());
#			my $fields = $F->get_fields(
#				{
#					lang_id        => 1,
#					$self->config->{ $G->get_path() }
#				}
#			);
#				my @f;
#
#				my $cont;
#				my $content_num = 0;
#				$cont = $C->get_grid(
#					{
#						fields			=> $fields,
#						lang_id         => 1,
#						parent_id       => $r->get_id(),
#						order_id        => $order_by,
#						order_direction => $direction,
#						offset          => $self->request->url->get_page() * $limit,
#						limit           => $limit,
#						count_all       => \$content_num
#					}
#				);
#
#				foreach ( @$cont ) {
#					if( $$re1[-1] ) {
#						$_->{href} = ( $self->config->{ $G->get_path() }->{href} ) . '/' . $$re1[-1]->get_name() . '/' . $_->{name} . '.html';
#					}
#					else {
#						$_->{href} = ( $self->config->{ $G->get_path() }->{href} ) . '/' . $r->get_name() . '/' . $_->{name} . '.html';
#					}
#
#					my $I = new HellFire::Article::ItemDAO( $self->dbh, $G );
#					$I->load( $_->{id}, { lang_id => 1 } );
#					my $File = new HellFire::File::ItemDAO( $self->dbh, $G );
#					my $gfs = $File->get_files_by_group( $I, { file_group_limit => $self->config->{ $G->get_path() }->{file_group_limit} } );
#
#					$_->{files_by_group} = $gfs;
#				}
#
#				my $href;
#				if( $self->config->{ $G->get_path() }->{href} ) {
#					$href = ( $self->config->{ $G->get_path() }->{href} ) . '/' . $r->get_name();
#				}
#				else {
#					$href = '/' . $C->get_name() . '/' . $r->get_name();
#				}
#
#				push(
#					@_re,
#					{
#						name        => $r->get_name(),
#						alias       => $r->get_alias( $G->get_lang_id() ),
#						id          => $r->get_id(),
#						href        => $href,
#						filter      => \@f,
#						rows        => $cont,
#						content_num => $content_num
#					}
#				);
#
#			}
#			push @menus, { rows => \@_re };
#		}
#		elsif( $$url[-1] eq 'content' ) {
#			my $re1 = $self->url_to_category( $G, $pid, [ split( /\//, $ENV{REQUEST_URI} ) ] );
#
#			my $C = new HellFire::Article::CategoryDAO( $self->dbh, $G );
#			$C->load( $pid, { lang_id => 1 } );
#
#			my $content_num = 0;
#			my $F = new HellFire::Article::FieldDAO( $self->dbh, $G );
#			my $fields = $F->get_fields(
#				{
#					lang_id        => 1,
#					$self->config->{ $G->get_path() }
#				}
#			);
#			my $cont        = $C->get_grid(
#				{
#					#no_fields       => 1,
#					fields => $fields,
#					lang_id         => 1,
#					parent_id       => $pid,
#					order_id        => $order_by,
#					order_direction => $direction,
#					offset          => $self->request->url->get_page() * $limit,
#					limit           => $limit,
#					count_all       => \$content_num
#				}
#			);
#
#			foreach ( @$cont ) {
#				if( $$re1[-1] ) {
#					$_->{href} = ( $self->config->{ $G->get_path() }->{href} ) . '/' . $$re1[-1]->get_name() . '/' . $_->{name} . '.html';
#				}
#				else {
#					$_->{href} = ( $self->config->{ $G->get_path() }->{href} ) . '/' . $C->get_name() . '/' . $_->{name} . '.html';
#				}
#
#				my $I = new HellFire::Article::ItemDAO( $self->dbh, $G );
#				$I->load( $_->{id}, { lang_id => 1 } );
#				my $File = new HellFire::File::ItemDAO( $self->dbh, $G );
#				my $gfs = $File->get_files_by_group( $I, { file_group_limit => $self->config->{ $G->get_path() }->{file_group_limit} } );
#
#				$_->{files_by_group} = $gfs;
#			}
#
#			push @menus, { rows => $cont };
#		}
#
#	}
#	elsif( $page_type eq 'index' || !$is_page ) {
#		my $C = new HellFire::Article::CategoryDAO( $self->dbh, $G );
#		$C->load( $pid, { lang_id => 1 } );
#		my $F = new HellFire::Article::FieldDAO( $self->dbh, $G );
#		$F->set_parent_id( $pid );
#		my $fields = $F->get_fields(
#			{
#				lang_id        => 1,
#				with_fields    => $self->config->{ $G->get_path() }->{with_fields},
#				without_fields => $self->config->{ $G->get_path() }->{without_fields}
#			}
#		);
#
#		my @dede;
#		my $rere = undef;
#		foreach ( keys %ITEMS ) {
#			push @dede, $ITEMS{$_};
#		}
#		$rere = collection_intersection( @dede ) if( scalar @dede );
#
#		$eee = $C->get_grid(
#			{
#				parent_id       => $pid,
#				order_id        => $order_by,
#				order_direction => $direction,
#				offset          => $self->request->url->get_page() * $limit,
#				limit           => $limit,
#				fields          => $fields,
#				id_in           => $rere,
#				count_all       => \$rowsc
#			}
#		);
#
#		my $t = join( '/', @$url );
#        my $href = $self->config->{ $G->get_path() }->{href} || $G->get_path() . '/' . $t;
#        $href =~ s/\/$//;
#        $href =~ s/\/_p\/(\d+)(\/)?//;
#        $href =~ s/\/$//;
#
#		foreach my $rr ( @$fields ) {
#            push @header, {
#                id => $rr->get_id(),
#                alias => $rr->get_alias( $G->get_lang_id ) || $rr->get_name(),
#                $rr->get_name() => 1,
#                href => $href
#            };
#        }
#
#		# need to clean
#		my $query = 'select * from file_items where item_id = ? and parent_id = ? order by name, parent_img';
#		my $sth   = $self->dbh->prepare( $query );
#		foreach ( @$eee ) {
#			my $I = new HellFire::Article::ItemDAO( $self->dbh, $G );
#			$I->load( $_->{id}, { lang_id => 1 } );
#			$_->{name}        = $I->get_name();
#			$_->{inserted}    = $I->get_inserted();
#			$_->{description} = $I->get_description( $G->get_lang_id() );
#			$_->{href}        = $href . '/' . $_->{name} . '.html', $_ = { %{$_}, %{ $I->parse_mysql_date( $I->get_inserted ) } };
#
#			$_->{inserted} =~ /(\d+)-(\d+)-(\d+) /;
#			$_->{inserted_year}  = $1;
#			$_->{inserted_month} = $2;
#			$_->{inserted_day}   = $3;
#
#			my @files;
#			my $File = new HellFire::File::ItemDAO( $self->dbh, $G );
#			$sth->execute( $I->get_id(), $File->find_by_prefix( 'article/item' ) ) or die;
#
#			my $pim = 0;
#
#			while ( my $h = $sth->fetchrow_hashref() ) {
#				$h->{type_name} = $self->dbh->selectrow_array( 'select name from settings_items where id = ? ', undef, $h->{type} );
#				$h->{ $h->{type_name} } = 1;
#
#				$h->{parent_name} = $self->dbh->selectrow_array( 'select if(alias,alias,name) from file_items where id = ? ', undef, $h->{parent_img} ) || '-';
#				$h->{user_name} = $self->dbh->selectrow_array( 'select name from user_items where id = ? ', undef, $h->{user_id} ) || '';
#
#				my $ff = $G->ini->document_root . $h->{url};
#				$h->{src}  = $h->{url};
#				$h->{href} = $_->{href};
#				$h->{size} = ( stat( $ff ) )[7];
#				$h->{size} = $File->format_size( $h->{size} );
#
#				unless( $pim ) {
#					$pim = $h->{parent_img};
#					unless( $pim ) {
#						$pim = $h->{id};
#					}
#				}
#
#				if( $pim == $h->{parent_img} || $pim == $h->{id} ) {
#					$h->{__first_file__} = 1;
#				}
#
#				push @files, $h;
#			}
#			$_->{files} = \@files;
#		}
#
#		$_title       = $C->get_alias( $G->get_lang_id() );
#		$_keywords    = $C->get_alias( $G->get_lang_id() );
#		$_description = $C->get_alias( $G->get_lang_id() );
#	}
#	elsif( $page_type eq 'level' ) {
#		my $C = new HellFire::Article::CategoryDAO( $self->dbh, $G );
#		$C->load( $pid, { lang_id => 1 } );
#		$_title       = $C->get_alias( $G->get_lang_id() );
#		$_keywords    = $C->get_alias( $G->get_lang_id() );
#		$_description = $C->get_alias( $G->get_lang_id() );
#	}
#	elsif( $is_page ) {
#		my $I = new HellFire::Article::ItemDAO( $self->dbh, $G );
#
#		#$I->set_parent_id( $Config->{ $G->get_path() }->{category_id} );
#		$I->set_parent_id( $pid );
#		$I->load( $I->find( $is_page ), { lang_id => 1 } );
#
#		return undef unless( $I->get_id() );
#
#		$self->request->response->set_crumbs( { name => $I->get_alias( $G->get_lang_id() ) } );
#
#		#if( $I->is_cache ) {
#		#$self->set_header( { -'last-modified' => HTTP::Date::time2str(HTTP::Date::str2time(HTTP::Date::parse_date( $I->get_updated ))) } );
#		#}
#
#		$item->{id}       = $I->get_id();
#		$item->{name}     = $I->get_name();
#		$item->{inserted} = $I->get_inserted();
#		$item->{content}  = $I->get_content( $G->get_lang_id() );
#		$item->{alias}    = $I->get_alias( $G->get_lang_id() );
#
#		$item->{inserted} =~ /(\d+)-(\d+)-(\d+) /;
#		$item->{inserted_year}  = $1;
#		$item->{inserted_month} = $2;
#		$item->{inserted_day}   = $3;
#
#		my $F = new HellFire::Article::FieldDAO( $self->dbh, $G );
#		$F->set_parent_id( $I->get_parent_id() );
#
#		#my $fields = $F->get_fields();
#		my $fields = $F->get_fields(
#			{
#				lang_id        => 1,
#				with_fields    => $self->config->{ $self->guard->get_path() }->{with_page_fields},
#				without_fields => $self->config->{ $self->guard->get_path() }->{without_page_fields}
#			}
#		);
#
#		foreach ( @$fields ) {
#			my $V = new HellFire::Article::ValueDAO( $self->dbh, $G );
#			my $T = new HellFire::DataType( $self->dbh );
#			$V->set_item_id( $I->get_id() );
#			$V->set_parent_id( $_->get_id() );
#			$V->set_type( $T->get_type_name( $_->get_type_id() ) );
#			$V->set_type_id( $_->get_type_id() );
#			$V->load();
#			my $oo = join( ',', @{ $V->get_value() } );
#			$oo =~ s/\"/&quot;/g unless( $T->get_type_name( $_->get_type_id() ) eq 'text' );
#			push @fili, { id => $_->get_id(), alias => $_->get_alias( $G->get_lang_id() ) || $_->get_name(), value => $oo, 'type_' . $V->get_type() => 1, $_->get_name() => 1 };
#		}
#
#		if( $self->config->{ $G->get_path() }->{file_management} == 2 ) {
#			my $File = new HellFire::File::ItemDAO( $self->dbh, $G );
#			my $gfs = $File->get_files_by_group( $I, $self->config->{ $G->get_path() }  );
#
#			$item->{files_by_group}   = $gfs;
#		}
#		else {
#
#			my $File  = new HellFire::File::ItemDAO( $self->dbh, $G );
#			my $query = 'select * from file_items where item_id = ? and parent_id = ? order by name, parent_img';
#			my $sth   = $self->dbh->prepare( $query );
#			$sth->execute( $I->get_id(), $File->find_by_prefix( 'article/item' ) ) or die;
#
#			my $pim = 0;
#
#			while ( my $h = $sth->fetchrow_hashref() ) {
#				$h->{type_name} = $self->dbh->selectrow_array( 'select name from settings_items where id = ? ', undef, $h->{type} );
#				$h->{ $h->{type_name} } = 1;
#				$h->{parent_name} = $self->dbh->selectrow_array( 'select if(alias,alias,name) from file_items where id = ? ', undef, $h->{parent_img} ) || '-';
#				$h->{user_name} = $self->dbh->selectrow_array( 'select name from user_items where id = ? ', undef, $h->{user_id} ) || '';
#
#				my $ff = $G->ini->document_root . $h->{url};
#				$h->{src}  = $h->{url};
#				$h->{size} = ( stat( $ff ) )[7];
#				$h->{size} = $File->format_size( $h->{size} );
#
#				unless( $pim ) {
#					$pim = $h->{parent_img};
#					unless( $pim ) {
#						$pim = $h->{id};
#					}
#				}
#
#				if( $pim == $h->{parent_img} || $pim == $h->{id} ) {
#					$h->{__first_file__} = 1;
#				}
#
#				$query = '( select * from file_items where parent_img = ? and type = ? )
#										limit 1';
#
#				my $TIM = $self->dbh->selectrow_hashref( $query, undef, $h->{parent_img}, $self->config->{ $self->guard->get_path() }->{ 'pair_image_' . $h->{type} } );
#
#				if( $TIM ) {
#					$h->{pair_src} = $TIM->{url};
#				}
#
#				push @files, $h;
#			}
#
#		}
#
#		if( 0 && eval "require HellFire::Article::CommentDAO" ) {
#			require HellFire::Article::CommentDAO;
#			my $CC = new HellFire::Article::CommentDAO( $self->{_dbh}, $G );
#			my $c = $CC->get_comments( { per_page => 1000, parent_id => $I->get_id() } );
#			foreach ( @$c ) {
#				push @cmt, { inserted => $_->get_inserted(), name => $_->get_name(), subject => $_->get_subject(), comment => $_->get_comment() };
#			}
#
#		}
#
#		$_title       = $I->get_alias( $G->get_lang_id() );
#		$_keywords    = $I->get_alias( $G->get_lang_id() );
#		$_description = $I->get_alias( $G->get_lang_id() );
#
#	}
#
#	my $ref = ref $O;
#	my $SSI = new CGI::SSI_M( dbh => $self->dbh, q => $q, guard => $G, request => $self->request );
#
#	my $out;
#	my $CO = $O;
#	my $CM;
#
#	if( $ref eq 'HellFire::Site::CategoryDAO' ) {
#		my $I = new HellFire::Site::ItemDAO( $self->dbh, $G );
#		$I->set_parent_id( $O->get_id() );
#
#		if( $self->config->{ $self->guard->get_path() }->{"index_template_$pid"} ) {
#			$I->load( $I->find( $self->config->{ $self->guard->get_path() }->{"index_template_$pid"} ) );
#		}
#		elsif( $page_type eq 'level' ) {
#			$I->load( $I->find( 'level.html' ) );
#		}
#		elsif( $is_page ) {
#			$I->load( $I->find( 'item.html' ) );
#		}
#		else {
#			$I->load( $I->find( 'index.html' ) );
#		}
#
#		$CM = new HellFire::Site::ItemDAO( $self->dbh, $G );
#		$CM->set_parent_id( $O->get_id() );
#		$CM->load( $I->find( '.context_menu.html' ) );
#		$CO = $I;
#	}
#
#	$ENV{DOCUMENT_TITLE}       .= $CO->get_title( $G->get_lang_id() ) . ' ' . $_title       unless( $ENV{DOCUMENT_TITLE} );
#	$ENV{DOCUMENT_ALIAS}       .= $CO->get_alias( $G->get_lang_id() ) . ' ' . $_title       unless( $ENV{DOCUMENT_ALIAS} );
#	$ENV{DOCUMENT_KEYWORDS}    .= $CO->get_keywords( $G->get_lang_id() ) . ' ' . $_title    unless( $ENV{DOCUMENT_KEYWORDS} );
#	$ENV{DOCUMENT_DESCRIPTION} .= $CO->get_description( $G->get_lang_id() ) . ' ' . $_title unless( $ENV{DOCUMENT_DESCRIPTION} );
#
#	my $S      = $self->request->domain();
#	my $prefix = $S->get_id();
#	$prefix .= '/t';
#
#	my $prefixc = $S->get_id();
#	$prefixc .= '/c/' . $CO->get_parent_id();
#
#	my $query = 'select * from site_templates t, site_template_content c where c.parent_id = t.id and lang_id = ? and t.id = ?';
#	my $TT = $self->dbh->selectrow_hashref( $query, undef, $G->get_lang_id(), $CO->get_template_id() );
#
#	unless( $ENV{DOCUMENT_CRUMBS} ) {
#		$ENV{DOCUMENT_CRUMBS} = 1;
#		my $N = new HellFire::Request( $self->dbh, $G, $q );
#		$N->request( '/include/crumbs.html' );
#		my $tpl1 = HTML::Template::Pro->new(
#			'die_on_bad_params' => 0,
#			'loop_context_vars' => 1,
#			'scalarref'         => \$N->response->content,
#		);
#		$tpl1->param( crumbs => $self->request->response->get_crumbs() );
#
#		$ENV{DOCUMENT_CRUMBS} = $tpl1->output();
#	}
#
#	my $cm_body;
#=head
#	if( ( stat( $G->ini->template_dir . "/$prefixc/" . $CM->get_content( $G->get_lang_id() ) ) )[7] > 0
#		&& open( FILE, $G->ini->template_dir . "/$prefixc/" . $CM->get_content( $G->get_lang_id() ) ) )
#	{
#		$cm_body = $SSI->process( join( '', <FILE> ) );
#		close FILE;
#	}
#
#	unless( $ENV{CONTEXT_MENU} )	{
#	    $ENV{CONTEXT_MENU} = $cm_body;
#	    $ENV{IS_CONTEXT_MENU} = 1;
#	}
#=cut
#	if( $CM )    {
#            my $cm_body;
#            if( ( stat( $G->ini->template_dir."/$prefixc/".$CM->get_content( $G->get_lang_id() ) ))[7]  > 0 &&
#                    open( FILE, $G->ini->template_dir."/$prefixc/".$CM->get_content( $G->get_lang_id() ) ) ) {
#		$cm_body = $SSI->process( join( '', <FILE> ) );
#                close FILE;
#
#                if( $cm_body && !$ENV{CONTEXT_MENU} )    {
#                    $ENV{CONTEXT_MENU} = $cm_body;
#                    $ENV{IS_CONTEXT_MENU} = 1;
#                }
#            }
#        }
#
#
#
#	if( ( stat( $G->ini->template_dir . "/$prefix/" . $TT->{top} ) )[7] > 0
#		&& open( FILE, $G->ini->template_dir . "/$prefix/" . $TT->{top} ) )
#	{
#		$out .= $SSI->process( join( '', <FILE> ) );
#		close FILE;
#	}
#
#	my $body;
#	if( ( stat( $G->ini->template_dir . "/$prefixc/" . $CO->get_content( $G->get_lang_id() ) ) )[7] > 0
#		&& open( FILE, $G->ini->template_dir . "/$prefixc/" . $CO->get_content( $G->get_lang_id() ) ) )
#	{
#		$body = join( '', <FILE> );
#		close FILE;
#	}
#	my $tpl = HTML::Template::Pro->new(
#		'die_on_bad_params' => 0,
#		'loop_context_vars' => 1,
#		'scalarref'         => \$body,
#	);
#
#	#$tpl->param( crumbs => $self->request->response->get_crumbs() );
#	$tpl->param( parent_id => $pid );
#	$tpl->param( menus     => \@menus );
#	$tpl->param( rows      => $eee || () );
#	$tpl->param( rows_count => $rowsc || 0 );
#	$tpl->param( paging    => $self->get_paging( { rows => $rowsc, limit => $limit, offset => $self->request->url->get_page(), url => $G->get_path() . '/-' . join( '/', @$url ) } ) );
#	$tpl->param( header    => \@header );
#	$tpl->param( $item );
#	$tpl->param( field_value => \@fili )  if( $is_page );
#	$tpl->param( files       => \@files ) if( $is_page );
#	$tpl->param( filter      => \@filter );
#	$tpl->param( filter_show_search_button => $ret_f->{show_search_button} );
#	$tpl->param( filter_selected           => \@filter_selected );
#	$tpl->param( comments                  => \@cmt ) if( $is_page );
#	$tpl->param( ss                        => $G->set_secure_string() );
#
#	#$tpl->param( rows => $eee );
#	#$out .= $tpl->output();
#	$out .= $SSI->process( $tpl->output() );
#
#	#$out .=  $tpl->output();
#
#	if( ( stat( $G->ini->template_dir . "/$prefix/" . $TT->{bottom} ) )[7] > 0
#		&& open( FILE, $G->ini->template_dir . "/$prefix/" . $TT->{bottom} ) )
#	{
#		$out .= $SSI->process( join( '', <FILE> ) );
#		close FILE;
#	}
#
#	#$self->request->response->header( 'Last-Modified', $self->dbh->selectrow_array( 'select date_format(?,"%a, %d %b %y %H:%i:%s GMT")', undef, $CO->get_updated ) );
#	$self->request->response->content( $out );
#}



#
#sub collection_intersection {
#
#	#my $self = shift;
#	my @cols = @_;
#
#	my $first = shift @cols;
#	my @res   = @$first;
#	if( scalar @cols > 0 ) {
#		foreach my $a ( @cols ) {
#			my %temp = ();
#			@temp{@res} = ( 1 ) x @res;
#			@res = grep $temp{$_}, @$a;
#		}
#	}
#
#	return \@res;
#}
#
#sub get_filter {
#	my $self   = shift;
#	my $params = shift;
#	my $ret;
#
#	my $F = new HellFire::Article::FieldDAO( $self->dbh, $self->guard );
#	$F->set_parent_id( $params->{pid} );
#	my $ff = $F->get_fields(
#		{
#			lang_id        => 1,
#			with_fields    => $self->config->{ $self->guard->get_path() }->{with_filter_fields},
#			without_fields => $self->config->{ $self->guard->get_path() }->{without_filter_fields}
#		}
#	);
#
#	my $url = $self->request->url->get_location;
#
#	if( $params->{append_url} ) {
#		$url .= $params->{append_url};
#	}
#
#	foreach ( @$ff ) {
#
#		#my $I = new HellFire::Article::ItemDAO( $self->dbh, $self->guard );
#		#my $ii = $I->get_all_siblings_id( $_->get_source_id(), { lang_id => 1 } );
#		#my $ii_join = join( ',', @$ii, -1);
#		#undef $ii;
#
#		my @other_items;
#
#		#my $own;
#		foreach my $k ( keys %{ $params->{items} } ) {
#			if( $_->get_id() != $k ) {
#				push @other_items, $params->{items}->{$k};
#			}
#
#			#else	{
#			#	$own = $params->{items}->{$k};
#			#}
#		}
#
#		my $other = [];
#		$other = collection_intersection( @other_items ) if( scalar @other_items );
#		undef @other_items;
#
#		my @myid = ( -1 );
#		unless( $self->config->{ $self->guard->get_path() }->{ simple_filter } ) {
#		foreach my $f ( @{ $params->{filter_id} } ) {
#			$f =~ /(\d+):(\d+)/;
#			if( $1 == $_->get_source_group_id() ) {
#				push @myid, $2;
#			}
#		}
#		}
#
#		my $sth = $self->dbh->prepare( 'call base_filter_block(?,?,?,?,?,?,?,?,?,?,?)' );
#		$sth->execute( 'article', $params->{pid}, $_->get_id(), $_->get_type_id, $_->get_source_group_id(), $_->get_source_id(), $_->get_source_field_id(), $self->guard->get_lang_id(), $self->guard->get_user_id(), join( ',', @myid ), join( ',', @$other ), );
#
#		my @values;
#		while ( my $h = $sth->fetchrow_hashref() ) {
#			my $href = $url;
#			$href .= '/filter/';
#			$href .= join( '_', sort( @{ $params->{filter_id} }, $_->get_source_group_id() . ':' . $h->{id} ) );
#			$href .= '?' . $self->request->url->get_query if( $self->request->url->get_query );
#			$h->{alias} ||= $h->{name} if( $_->get_type eq 'reference' );
#			$h->{href} = $href;
#
#			  foreach my $f ( @{ $params->{filter_id} } ) {
#                    $f =~ /(\d+):(\d+)/;
#                    if( $1 == $_->get_source_group_id() && $2 == $h->{id} ) {
#                        $h->{selected} = 1;
#                    }
#                }
#
#			if( $_->get_type() ne 'reference' ) {
#				$h->{type_text}            = 1;
#				$ret->{show_search_button} = 1;
#			}
#
#			push @values, $h;
#		}
#
#=head
#		#my $query = 'select v.value, count(*) count from article_items i inner join article_values_reference v on v.item_id = i.id and i.parent_id = ? inner join article_items b on b.id = v.value inner join article_item_aliases a on a.parent_id = b.id and a.lang_id = ? where v.parent_id = ? and v.value in ('.$ii_join.') and v.value not in ('.join(',',@{$params->{filter_id}},-1).') ';
#		my $query = 'select v.value, count(*) count from article_items i inner join article_values_reference v on v.item_id = i.id and i.parent_id = ? inner join reference_items b on b.id = v.value inner join reference_item_aliases a on a.parent_id = b.id and a.lang_id = ? where v.parent_id = ? and v.value in ('.$ii_join.') and v.value not in ('.join(',',@{$params->{filter_id}},-1).') ';
#		$query .= ' and i.id in('.join(',',@$other,-1).') ' if( $other );
#		$query .= ' group by 1 order by b.name';
#
#		my $sth = $self->dbh->prepare( $query );
#		$sth->execute( $params->{pid}, $self->guard->get_lang_id(), $_->get_id() );
#
#		my @values;
#		while( my $h = $sth->fetchrow_hashref() )	{
#			my $href = $url;
#			$href .= '/filter/';
#			$href .= join( '_', sort(@{$params->{filter_id}}, $h->{value}) );
#
#			$I->load( $h->{value}, { lang_id => 1 } );
#
#			$h->{ alias } = $I->get_alias( $self->guard->get_lang_id() );
#			$h->{ href } = $href;
#
#			push @values, $h;
#		}
#
#		if( $own )	{
#			my $query = 'select v.value, count(*) count from article_items i inner join article_values_reference v on v.item_id = i.id and i.parent_id = ? inner join article_items b on b.id = v.value inner join article_item_aliases a on a.parent_id = b.id and a.lang_id = ? where v.parent_id = ? and v.value in ('.$ii_join.') and v.value not in ('.join(',',@{$params->{filter_id}},-1).') and i.id in('.join(',',@$own,-1).') group by 1 ';
#
#			my $sth = $self->dbh->prepare( $query );
#			$sth->execute( $params->{pid}, $self->guard->get_lang_id(), $_->get_id() );
#
#			foreach my $v ( @values )	{
#				$v->{count} = '+'.$v->{count};
#			}
#
#			while( my $h = $sth->fetchrow_hashref() )	{
#				foreach my $v ( @values )	{
#					if( $v->{value} == $h->{value} )	{
#						$v->{count} = $h->{count};
#						last;
#					}
#				}
#			}
#		}
#=cut
#
#		push @{ $params->{filter} }, {
#				id => $_->get_id(),
#				source_group_id => $_->get_source_group_id(),
#				alias => $_->get_alias( $self->guard->get_lang_id() ) || $_->get_name(),
#				$_->get_name() => 1,
#				values => \@values
#				};
#	}
#	return $ret;
#}

#sub DESTROY {
#	my $self = shift;
#	undef $self->{_config};
#}
#


return 1;
