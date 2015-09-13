#!/usr/bin/perl

use strict;
use lib $ENV{'DOCUMENT_ROOT'} . '/../lib';
use lib $ENV{'DOCUMENT_ROOT'} . '/lib';
use lib $ENV{'DOCUMENT_ROOT'} . './lib';
use CGI::Minimal;
use HellFire::DataBase;
use HellFire::Guard;
use HellFire::Config;
use JSON;
use HellFire::Response;
use HellFire::Article::ItemDAO;

#use HellFire::Article::FieldDAO;
#use HellFire::Article::ValueDAO;
#use HellFire::Settings::CategoryDAO;
#use HellFire::File::ItemDAO;

#use HellFire::User::CategoryDAO;
#use HellFire::User::ItemDAO;

my $INI = new HellFire::Config();

my $B   = new HellFire::DataBase( $INI );
my $dbh = $B->connect();

my $q = new CGI::Minimal;
my $G = new HellFire::Guard( $dbh, $q, $INI );
$G->check_session();

my $R = new HellFire::Response;
my $J = new JSON;
print $R->header( 'Content-Type' => 'text/x-json;charset=utf-8' );

my $parent_id = $q->param( 'parent_id' ) || $q->param( 'pid' ) || 0;
my $id        = $q->param( 'id' )        || 0;
my $action    = $q->param( 'action' )    || '';

#---------------------------------------------------------------

if( $action eq 'article_item_list' ) {
	my $C = new HellFire::Article::ItemDAO( $dbh, $G );

	my $order_by  = $q->param( 'sort' )  || 'ordering';
	my $direction = $q->param( 'dir' )   || 'desc';
	my $start     = $q->param( 'start' ) || 0;
	my $limit     = $q->param( 'limit' ) || 50;
	my $rowsc     = 0;

	my $eee = $C->get_grid(
		{
			parent_id       => $parent_id,
			order_by        => $order_by,
			order_direction => $direction,
			offset          => $start,
			limit           => $limit,
			count_all       => \$rowsc,
			with_hidden     => 1,
			with_alias      => 1,
			with_inserted   => 1,
			with_name       => 1,
			with_ordering   => 1
		}
	);

	my $res;
	$res->{metaData} = {
		id              => "id",
		root            => "rows",
		totalProperty   => "totalCount",
		successProperty => "success",
		fields          => [ { name => "id" }, { name => "name" }, { name => "inserted" }, { name => "alias", mapping => "alias" }, { name => "ordering" } ],
		sortInfo        => {
			field     => $order_by,
			direction => $direction
		}
	};
	$res->{totalCount} = $rowsc;
	$res->{rows}       = $eee;
	$res->{columns}    = [
		{ dataIndex => "id",       header => "labelID",       sortable => 'true' },
		{ dataIndex => "name",     header => "labelName",     sortable => 'true' },
		{ dataIndex => "alias",    header => "labelAlias",    sortable => 'true' },
		{ dataIndex => "inserted", header => "labelInserted", sortable => 'true' },
		{ dataIndex => "user_id",  header => "labelOwner",    sortable => 'true' },
		{ dataIndex => "ordering", header => "#",             sortable => 'true' }
	];

	print( $J->encode( $res ) );
	exit 0;
}

if( $action eq 'article_item_view' ) {
	require HellFire::Configuration::ItemDAO;
	require HellFire::User::ItemDAO;
	require HellFire::Article::CategoryDAO;
	require HellFire::DataType;

	my $I = new HellFire::Article::ItemDAO( $dbh, $G );
	$I->load( $id, { no_clean => 1 } );

	my $res = $I->to_template();

	my $U = new HellFire::User::ItemDAO( $dbh, $G );
	$U->load( $I->get_user_id() );
	$res->{owner} = $U->get_name() || $U->get_name();

	my $S = new HellFire::Article::CategoryDAO( $dbh, $G );
	$S->load( $I->get_parent_id() );
	$res->{parent_name} = $S->get_name();

	my $T = new HellFire::DataType( $dbh );
	my $l = $T->get_languages();

	my $l10n = {
		xtype          => 'tabpanel',
		activeTab      => 0,
		width          => '100%',
		autoHeight     => 1,
		deferredRender => 0,
		forceLayout    => 1,
		defaults       => {
			bodyStyle => 'padding:10px',
			anchor     => '100%'
		},
		items => []
	};

	my $tpl = {
		xtype          => 'tabpanel',
		activeTab      => 0,
		width          => '100%',
		autoHeight     => 1,
		deferredRender => 0,
		forceLayout    => 1,
		defaults       => {
			bodyStyle => 'padding:10px',
			anchor     => '100%'
		},
		items => []
	};

	foreach ( @$l ) {
		my $lang = {
			title      => $_->{alias},
			layout     => 'form',
			autoHeight => 1,
			defaults   => {
				anchor     => '100%',
				bodyStyle => 'border:0'
			},
			items => []
		};

		my $tlang = {
			title      => $_->{alias},
			layout     => 'form',
			autoHeight => 1,
			bodyStyle  => 'padding:0',
			defaults   => {
				anchor     => '100%',
				bodyStyle => 'border:0;padding:0'
			},
			items => []
		};

		push @{ $lang->{items} },
		  {
			xtype      => 'textfield',
			fieldLabel => 'labelAlias',
			name       => 'alias_' . $_->{id},
			value      => $I->get_alias( $_->{id} )
		  };

		push @{ $lang->{items} },
		  {
			xtype      => 'textfield',
			fieldLabel => 'labelTitle',
			name       => 'title_' . $_->{id},
			value      => $I->get_title( $_->{id} )
		  };

		push @{ $lang->{items} },
		  {
			xtype      => 'textarea',
			fieldLabel => 'labelKeywords',
			height     => 100,
			name       => 'keywords_' . $_->{id},
			value      => $I->get_keywords( $_->{id} )
		  };

		push @{ $lang->{items} },
		  {
			xtype      => 'textarea',
			fieldLabel => 'labelDescription',
			height     => 100,
			name       => 'description_' . $_->{id},
			value      => $I->get_description( $_->{id} )
		  };

		push @{ $tlang->{items} }, {
			xtype     => 'ckeditor',
			language  => $1,
			hideLabel => 1,
			name      => 'content_' . $_->{id},
			id        => 'content_' . $I->get_id() . '_' . $_->{id},
			CKConfig => { customConfig => '/cgi-bin/wg/modules/article/template/js/ck_config.js' },
			value    => $I->get_content( $_->{id} )
		};

		push @{ $l10n->{items} }, $lang;
		push @{ $tpl->{items} },  $tlang;
	}

	$res->{l10n} = $l10n;
	$res->{tpl}  = $tpl;

	my @items_flags;

	my $ff = $B->get_set_values( 'article_items', 'flags' );
	foreach ( @$ff ) {
		next if( $_ eq 'DELETED' );
		push @items_flags,
		  {
			xtype      => 'checkbox',
			fieldLabel => 'FLAG_' . $_,
			name       => 'article_flag',
			autoHeight => 1,
			checked    => $I->get_flag( $_ ),
			value      => $_,
			inputValue => $_
		  };
	}

	$res->{flags} = \@items_flags;

	print( $J->encode( $res ) );
	exit 0;
}

if( $action eq 'article_item_access_list' ) {
	my $I = new HellFire::Article::ItemDAO( $dbh, $G );
	$I->load( $id );
	my $rows = $I->get_access_list();

	my $res;
	$res->{metaData} = {
		id              => "id",
		root            => "rows",
		totalProperty   => "totalCount",
		successProperty => "success",
		fields          => [ { name => "group" }, { name => "group_id" }, { name => "action" }, { name => "action_id" }, { name => "value", type => "bool" } ],
		sortInfo        => {
			field     => 'action',
			direction => 'desc'
		}
	};
	$res->{totalCount} = scalar @$rows;
	$res->{rows}       = $rows;

	print( $J->encode( $res ) );
	exit 0;
}

if( $action eq 'article_item_add' ) {
	if( $q->param( 'parent_id' ) && $q->param( 'name' ) ) {
		my $I = new HellFire::Article::ItemDAO( $dbh, $G );
		$I->set_parent_id( $q->param( 'parent_id' ) );
		$I->set_name( $q->param( 'name' ) );
		$I->save();

		my $o;
		if( $I->get_id() ) {
			$o->{success} = 'true';
		}
		else {
			$o->{success} = 'false';
		}
		print( $J->encode( $o ) );
	}
	else {
		my $o;
		$o->{success} = 'false';
		print( $J->encode( $o ) );
	}
	
	exit 0;
}

if( $action eq 'article_item_update' || $action eq '_article_item_add' ) {
	my $I = new HellFire::Article::ItemDAO( $dbh, $G );
	#$I->load( $q->param( 'id' ) );

	foreach my $i ( $q->param() ) {
		if( $i eq 'article_flag' ) {
			foreach ( $q->param( 'article_flag' ) ) {
				$I->set_flag( $_ );
			}
		}
		elsif( $i =~ /alias_(\d+)/ ) {
			$I->set_alias( $1, $q->param( $i ) );
		}
		elsif( $i =~ /description_(\d+)/ ) {
			$I->set_description( $1, $q->param( $i ) );
		}
		elsif( $i =~ /title_(\d+)/ ) {
			$I->set_title( $1, $q->param( $i ) );
		}
		elsif( $i =~ /keywords_(\d+)/ ) {
			$I->set_keywords( $1, $q->param( $i ) );
		}
		elsif( $i =~ /content_(\d+)/ ) {
			$I->set_content( $1, $q->param( $i ) );
		}
		elsif( $i =~ /json_access/ ) {
			my $J = new JSON;
			my $code = $J->decode( $q->param( 'json_access' ) );
			foreach my $j ( @$code ) {
				if( $j->{value} eq 'false' || $j->{value} == 0 ) {
					$dbh->do( 'delete from article_item_access where parent_id = ? and group_id = ? and action_id = ?', undef, $q->param( 'id' ), $j->{group_id}, $j->{action_id} );
				}
				if( $j->{value} eq 'true' || $j->{value} > 0 ) {
					$dbh->do( 'insert ignore into article_item_access(parent_id,group_id,action_id) values(?,?,?)', undef, $q->param( 'id' ), $j->{group_id}, $j->{action_id} );
				}
			}
		}
		else {
			my $fn = 'set_'.$i;
			$I->$fn( $q->param( $i ) ) if( $I->can($fn) );
		}
	}

	$I->save();

	print( $J->encode( { success => 1 } ) );
	exit 0;
}

if( $action eq 'article_item_delete' ) {
	if( $q->param( 'id' ) ) {
		my @arr = split( /,/, $q->param( 'id' ) );
		foreach ( @arr ) {
			my $I = new HellFire::Article::ItemDAO( $dbh, $G );
			$I->load( $_ );
			$I->destroy();
		}
	}

	print( $J->encode( { success => 1 } ) );
	exit 0;
}

if( $action eq 'article_item_move' && $q->param( 'src' ) && $q->param( 'dst' ) ) {
	my $C = new HellFire::Article::ItemDAO( $dbh, $G );

	foreach ( split( /,/, $q->param( 'src' ) ) ) {
		$C->load( $_ );
		$C->move( $q->param( 'dst' ) );
	}

	print( $J->encode( { success => 1 } ) );
	exit 0;
}

if( $action eq 'article_item_ordering' && $q->param( 'src' ) && $q->param( 'dst' ) ) {
	my $C = new HellFire::Article::ItemDAO( $dbh, $G );

	if( $parent_id ) {
		$C->set_parent_id( $parent_id );
		$C->ordering( $q->param( 'src' ), $q->param( 'dst' ) );
	}

	print( $J->encode( { success => 1 } ) );
	exit 0;
}

if( $q->param( 'save_access' ) ) {
	my $query = 'delete from article_item_access where parent_id = ?';
	$dbh->do( $query, undef, $id );
	foreach ( $q->param() ) {
		if( $_ =~ /access_(\d+)_(\d+)/ ) {
			$dbh->do( 'insert into article_item_access(parent_id, group_id, action_id) values(?,?,?)', undef, $id, $1, $2 );
		}
	}
	$G->header( -location => 'item.cgi?id=' . $q->param( 'id' ) );
	exit 0;
}


if( $action eq 'article_item_files_list' )	{
	require HellFire::File::ItemDAO;
	
	my $I = new HellFire::Article::ItemDAO( $dbh, $G );
    $I->load( $id );
    
	my $F = new HellFire::File::ItemDAO( $dbh, $G );
	my $rows = $F->get_admin_files( $I, { with_size => 1, with_type_alias => 1 } );

	if( eval "require Image::Magick" )	{
		foreach( @$rows)	{
			if( !-e $ENV{DOCUMENT_ROOT}.$_->{src}.'.prev' &&
				( 	$F->get_extension( $_->{src} ) =~ /jpg/i ||
					$F->get_extension( $_->{src} ) =~ /jpeg/i  ||
					$F->get_extension( $_->{src} ) =~ /png/i )
					)	{
				my $IM = new Image::Magick;
				$IM->read( $ENV{DOCUMENT_ROOT}.$_->{src} );
				$IM->Set( quality => 70 );
				$IM->Thumbnail( geometry => '40x40', );
				$IM->write( $ENV{DOCUMENT_ROOT}.$_->{src}.'.prev' );
				undef $IM;
			}
			if( -f $ENV{DOCUMENT_ROOT}.$_->{src}.'.prev' )	{
				$_->{preview} = $_->{src}.'.prev';
			}
		}
	}
	
    my $res;
	$res->{metaData} = {
		id => "id",
        root => "rows",
        totalProperty => "totalCount",
        successProperty => "success",
        fields => [
			{ name => "id"},
			{ name => "preview" },
            #{ name => "type_name" },
			#{ name => "type_alias" },
			{ name => "type_name_alias" },
			{ name => "size" },
			{ name => "inserted" },
            { name => "src" },
            { name => "alias" }
        ],
        sortInfo => {
           field => 'type_name_alias',
           direction => 'desc'
        }
	};
    $res->{totalCount} = scalar @$rows;
    $res->{rows} = $rows;
	
	print( $J->encode( $res ) );
	exit 0;
}

if( $action eq 'article_item_file_type' ) {
	require HellFire::Settings::CategoryDAO;
	
	my $S = new HellFire::Settings::CategoryDAO( $dbh, $G );
	$S->find( 'file_types' );
	
	my $query = 'select i.id, if(length(a.alias),a.alias,i.name) alias from settings_items i left join settings_item_aliases a on a.parent_id = i.id and lang_id = ?
	where i.parent_id = ? and find_in_set("DELETED",flags) = 0 ';
	my $sth = $dbh->prepare( $query );
	$sth->execute( $G->get_lang_id(), $S->get_id() );
	my @arr;
	while ( my $hash = $sth->fetchrow_hashref() ) {
		push @arr, $hash;
	}
	
	print( $J->encode( \@arr ) );
	exit 0;
}



if( $action eq 'article_item_add_file' ) {
	require HellFire::File::ItemDAO;
	
	my $res;
	
	foreach ( $q->param( 'fileupload' ) ) {
		if( $q->param( 'type_id' )  )	{
			my $File = new HellFire::File::ItemDAO( $dbh, $G );
			$File->set_item_id( $q->param( 'id' ) );
			$File->set_type_id( $q->param( 'type_id' ) );
			$File->set_prefix( 'article/item' );
			$File->set_parent_id( $File->find_by_prefix( $File->get_prefix() ) );
			my $f2;
			$f2 = $q->param_filename('fileupload') if( $q->can('param_filename') );
			$File->upload( $_, $f2 );
			$File->process( { overwrite => $q->param( 'overwrite' ) || 0 } );
			$res = { success => 1 };
		}
		else	{
			$res = { success => 0, message => 'FAILED. No type' };
		}
	}
	
	print( $J->encode( $res ) );
	exit 0;
}

if( $action eq 'article_item_del_file' ) {
	require HellFire::File::ItemDAO;
	if( $q->param( 'fid' ) )	{
		foreach ( split( /,/, $q->param( 'fid' ) ) ) {
			my $File = new HellFire::File::ItemDAO( $dbh, $G );
			$File->load( $_ );
			$File->destroy();
		}
	}
	
	print( $J->encode( { success => 1 } ) );
	exit 0;
}



if( $action eq 'article_item_find_replace' ) {
	my $J = new JSON;
	my $o;
	$o->{success} = 'false';
	if( $q->param( 'find' ) && ( $q->param( 'parent_id' ) || $q->param( 'id' ) ) && $q->param( 'where_id' ) ) {
		my $ii = [];
		if( $q->param( 'area_id' ) == 2 ) {
			my $I = new HellFire::Article::ItemDAO( $dbh, $G );
			$I->set_parent_id( $q->param( 'parent_id' ) );
			$ii = $I->get_all_siblings();
		}
		else {
			foreach ( split( /,/, $q->param( 'id' ) ) ) {
				my $I = new HellFire::Article::ItemDAO( $dbh, $G );
				if( $I->load( $_ ) ) {
					push @$ii, $I;
				}
			}
		}

		my $F = new HellFire::Article::FieldDAO( $dbh, $G );
		$F->set_parent_id( $q->param( 'parent_id' ) );
		if( $q->param( 'where_id' ) == 3 ) {
			$F->load( $F->find( $q->param( 'field_name' ) ) );
		}

		my $find    = $q->param( 'find' );
		my $replace = $q->param( 'replace' );
		my $flags;
		unless( $q->param( 'case' ) ) {
			$flags .= 'i';
		}
		if( $q->param( 'replace_all' ) ) {
			$flags .= 'g';
		}

		foreach ( @$ii ) {
			if( $q->param( 'where_id' ) == 1 ) {    # alias
				my $str = $_->get_alias( $G->get_lang_id() );
				$str =~ s/$find/$replace/;
				$str =~ s/^\s+|\s+$//;
				$str =~ s/\s+/ /g;
				$_->set_alias( $G->get_lang_id, $str );
				$_->save();
			}
			elsif( $q->param( 'where_id' ) == 2 ) {    # name
				my $str = $_->get_name();
				$str =~ s/$find/$replace/;
				$str =~ s/^\s+|\s+$//;
				$str =~ s/\s+/ /g;
				$_->set_name( $str );
				$_->save();
			}
			elsif( $q->param( 'where_id' ) == 3 && $F->get_id() ) {    #field
				if( $F->get_type() eq 'reference' ) {
				}
				else {
					my $V = new HellFire::Article::ValueDAO( $dbh, $G );
					if( $V->load( $F, $_ ) ) {
						my $str = $V->to_string();
						$str =~ s/$find/$replace/;
						$str =~ s/^\s+|\s+$//;
						$str =~ s/\s+/ /g;
						$V->undef_value();
						$V->set_value( $str );
						$V->save();
					}
				}
			}
		}
	}

	$G->header( -type => "text/x-json" );
	print( $J->encode( $o ) );
	exit 0;

}

if( $action eq 'article_item_set_prop' ) {
	my $J = new JSON;
	my $o;
	$o->{success} = 0;

	if( $q->param( 'pid' ) && $q->param( 'fname' ) ) {
		my @ids;
		if( $q->param( 'all' ) ) {
			my $query = 'select id from article_items where parent_id = ?';
			my $sth   = $dbh->prepare( $query );
			$sth->execute( $q->param( 'pid' ) );
			while ( my @arr = $sth->fetchrow_array() ) {
				push @ids, $arr[0];
			}
		}
		else {
			@ids = split /,/, $q->param( 'id' );
		}
		warn join( ',', @ids );
		if( scalar @ids ) {
			my $F = new HellFire::Article::FieldDAO( $dbh, $G );
			$F->set_parent_id( $q->param( 'pid' ) );

			#$F->load( $F->find($q->param('fname')) );
			my $cols = $F->get_fields();
			foreach ( @$cols ) {
				if( $q->param( 'fname' ) eq $_->get_name() ) {
					$F = $_;
					last;
				}
			}

			my $T = new HellFire::DataType( $dbh );
			my $V = new HellFire::Article::ValueDAO( $dbh, $G );
			$V->set_parent_id( $F->get_id() );
			$V->set_type( $T->get_type_name( $F->get_type_id() ) );
			$V->set_type_id( $F->get_type_id() );

			if( $V->get_type() eq 'reference' ) {
				foreach ( split( /###/, $q->param( 'fval' ) ) ) {
					my $v = $dbh->selectrow_array( 'select id from article_items where name = ? and parent_id = ?', undef, $_, $F->get_source_id );
					$V->set_value( $v || 0 );
				}
			}
			else {
				$V->set_value( $q->param( 'fval' ) || '' );
			}

			#foreach( split( /,/, $q->param('id') ) )	{
			foreach ( @ids ) {
				$V->set_item_id( $_ );
				$V->save();
			}
		}

		$o->{success} = 1;
	}

	$G->header( -type => "text/x-json" );
	print( $J->encode( $o ) );
	exit 0;
}

if( $q->param( 'savefields' ) && $q->param( 'id' ) ) {
	my $V = new HellFire::Article::ValueDAO( $dbh, $G );
	my $T = new HellFire::DataType( $dbh );
	$V->set_item_id( $q->param( 'id' ) );

	foreach my $e ( $q->param() ) {
		if( $e =~ /field_(\d+)/ ) {
			my $F = new HellFire::Article::FieldDAO( $dbh, $G );
			$F->set_id( $1 );
			$F->load( $1 );

			$V->set_parent_id( $1 );
			$V->set_type( $T->get_type_name( $F->get_type_id() ) );
			$V->set_type_id( $F->get_type_id() );
			foreach my $w ( $q->param( "field_$1" ) ) {
				$V->set_value( $w );
			}

			$V->save();
			$V->undef_value();
		}
	}

	$G->header( 'Location' => 'item.cgi?id=' . $q->param( 'id' ) );
	exit 0;

}

if( $q->param( 'ordering' ) && $q->param( 'item_id' ) && $q->param( 'id' ) && $q->param( 'type' ) ) {
	my $query = 'select id, ordering from file_items where item_id = ? and parent_img = 0 and type = ? order by ordering desc';
	my $sth   = $dbh->prepare( $query );
	$sth->execute( $q->param( 'item_id' ), $q->param( 'type' ) );

	my @O;
	my $ord = 0;

	while ( my $h = $sth->fetchrow_hashref() ) {
		if( $q->param( 'ordering' ) eq 'up' && $h->{id} == $q->param( 'id' ) ) {
			if( $O[-1] ) {
				$dbh->do( 'update file_items set ordering = ? where id = ?', undef, $h->{ordering}, $O[-1]->{id} );
				$O[-1]->{ordering} += 10 if( $O[-1]->{ordering} eq $h->{ordering} );
				$dbh->do( 'update file_items set ordering = ? where id = ?', undef, $O[-1]->{ordering}, $h->{id} );
			}
			else {
				warn 1111;
				$dbh->do( 'update file_items set ordering = ordering + 10 where id = ?', undef, $h->{id} );
			}
			last;
		}

		if( $q->param( 'ordering' ) eq 'down' ) {
			if( $O[-1] && $O[-1]->{id} == $q->param( 'id' ) ) {
				$dbh->do( 'update file_items set ordering = ? where id = ?', undef, $h->{ordering}, $O[-1]->{id} );
				$O[-1]->{ordering} -= 10 if( $O[-1]->{ordering} eq $h->{ordering} );
				$dbh->do( 'update file_items set ordering = ? where id = ?', undef, $O[-1]->{ordering}, $h->{id} );
			}
			else {
				$dbh->do( 'update file_items set ordering = ordering - 10 where id = ?', undef, $h->{id} );
			}
			last;
		}

		warn $h->{id};
		push @O, $h;
	}

	$sth->finish;

	$G->header( 'Location' => 'item.cgi?id=' . $q->param( 'item_id' ) . '#files' );
	exit 0;
}

=head

$G->header();

my $template = new HTML::Template(
	filename          => 'template/edit.html',
	die_on_bad_params => 0,
	loop_context_vars => 1
);

my $I = new HellFire::Article::ItemDAO( $dbh, $G );
$I->load( $id );
my $UZ = new HellFire::User::ItemDAO( $dbh, $G );
$UZ->load( $I->get_user_id() );

$template->param(
	id        => $I->get_id(),
	parent_id => $I->get_parent_id(),
	name      => $I->get_name(),
	inserted  => $I->get_inserted(),
	updated   => $I->get_updated(),
	user_name => $UZ->get_name(),

	#alias => $I->get_alias( $G->get_lang_id ),
	ordering => $I->get_ordering()
);

my $T = new HellFire::DataType( $dbh );
my $l = $T->get_languages();
my @item_l10n;
foreach ( @$l ) {
	push @item_l10n,
	  {
		lang_name   => $_->{name},
		lang_id     => $_->{id},
		lang_alias  => $_->{alias},
		alias       => $I->get_alias( $_->{id} ),
		description => $I->get_description( $_->{id} ),
		title       => $I->get_title( $_->{id} ),
		keywords    => $I->get_keywords( $_->{id} ),
		content     => $I->get_content( $_->{id} )
	  };
}

$template->param( item_l10n => \@item_l10n );

my $F = new HellFire::Article::FieldDAO( $dbh, $G );
$F->set_parent_id( $I->get_parent_id() );
my $fields = $F->get_fields();

my @fili;

foreach ( @$fields ) {
	my $V = new HellFire::Article::ValueDAO( $dbh, $G );
	my $T = new HellFire::DataType( $dbh );
	$V->set_item_id( $id );
	$V->set_parent_id( $_->get_id() );
	$V->set_type( $T->get_type_name( $_->get_type_id() ) );
	$V->set_type_id( $_->get_type_id() );
	$V->load();
	my $oo = join( ',', @{ $V->get_value() } );

	#$oo =~ s/\"/&quot;/g unless( $V->get_type() eq 'text' );
	if( $V->get_type eq 'reference' ) {
		push @fili, { id => $_->get_id(), alias => $_->get_alias( $G->get_lang_id() ) || $_->get_name(), combo => $_->get_combo( $V->{_values} ), 'type_' . $V->get_type() => 1 };

	}
	else {
		push @fili, { id => $_->get_id(), alias => $_->get_alias( $G->get_lang_id() ) || $_->get_name(), value => $oo, 'type_' . $V->get_type() => 1 };
	}
}

$template->param( 'fields_loop' => \@fili );

my $fla = $B->get_set_values( 'article_items', 'flags' );

my @tl;
my $cc = 3;
foreach ( @$fla ) {
	next if( $_ eq 'DELETED' );
	push @tl, { name => $_, id => $cc++, checked => $I->get_flag( $_ ) ? 'checked' : '', $_ => 1 };
}
$template->param( 'flags_loop' => \@tl );

require HellFire::File::ItemDAO;

#my $File = new HellFire::File::ItemDAO( $dbh, $G );
#my $query = 'select * from file_items where item_id = ? and parent_id = ? order by name, parent_img';
#my $sth = $dbh->prepare( $query );
#$sth->execute($I->get_id(), $File->find_by_prefix('article/item') ) or die;

#my @arrf;
#while( my $h = $sth->fetchrow_hashref() )	{
#    $h->{type_name} = $dbh->selectrow_array('select alias from settings_item_aliases where parent_id = ? and lang_id = ?', undef, $h->{type}, $G->get_lang_id() );
#    $h->{type_name2} = $dbh->selectrow_array('select name from settings_items where id = ? ', undef, $h->{type} );
#    $h->{type_name} ||=  $h->{type_name2};
#    $h->{parent_name} = $dbh->selectrow_array('select if(alias,alias,name) from file_items where id = ? ', undef, $h->{parent_img} )||'-';
#    $h->{user_name} = $dbh->selectrow_array('select name from user_items where id = ? ', undef, $h->{user_id} )||'';
#}
#
#$template->param( 'file_list' => \@arrf );

my $File2 = new HellFire::File::ItemDAO( $dbh, $G );
my $gfs = $File2->get_files_by_group( $I );

if( require Image::Magick ) {

	foreach ( @$gfs ) {
		foreach ( @{ $_->{group_files} } ) {
			foreach ( @{ $_->{files} } ) {
				if( !$_->{parent_img} ) {
					if(
						!-e $ENV{DOCUMENT_ROOT} . $_->{src} . '.prev'
						&& (   $File2->get_extension( $_->{src} ) =~ /jpg/i
							|| $File2->get_extension( $_->{src} ) =~ /jpeg/i
							|| $File2->get_extension( $_->{src} ) =~ /png/i )
					  )
					{
						my $IM = new Image::Magick;
						$IM->read( $ENV{DOCUMENT_ROOT} . $_->{src} );
						$IM->Resize( geometry => '30x30' );
						$IM->write( $ENV{DOCUMENT_ROOT} . $_->{src} . '.prev' );
						undef $IM;
					}
					if( -f $ENV{DOCUMENT_ROOT} . $_->{src} . '.prev' ) {
						$_->{preview} = 1;
					}
				}
			}
		}
	}
}

$template->param( 'files_by_group' => $gfs );

my $S = new HellFire::Settings::CategoryDAO( $dbh );
$S->find( 'file_types' );
my $query = 'select i.id, if(length(a.alias),a.alias,i.name) alias from settings_items i left join settings_item_aliases a on a.parent_id = i.id and lang_id = ?
where i.parent_id = ? and find_in_set("DELETED",flags) = 0 ';
my $sth = $dbh->prepare( $query );
$sth->execute( $G->get_lang_id(), $S->get_id() );
my @arr;
while ( my $hash = $sth->fetchrow_hashref() ) {
	push @arr, $hash;
}

$template->param( 'file_types' => \@arr );

my $UC = new HellFire::User::CategoryDAO( $dbh, $G );
my $grp = $UC->get_all_siblings();
$UC->set_name( 'guest' );
$UC->set_id( 0 );
push @$grp, $UC;

require HellFire::Configuration::CategoryDAO;
my $UC = new HellFire::Configuration::CategoryDAO( $dbh, $G );
my $act = $UC->get_actions( $UC->find( 'article_lib' ) );

my @groups;
foreach ( @$grp ) {
	next if( $_->get_name() eq 'administrator' );
	my @access;
	foreach my $a ( @$act ) {
		my $val = $dbh->selectrow_array( 'select 1 from article_item_access where parent_id = ? and group_id = ? and action_id = ?', undef, $id, $_->get_id(), $a->{id} ) || 0;
		push @access, { name => $a->{name}, value => $val, id => $a->{id}, group_id => $_->get_id() } if( $a->{name} =~ /item/ );
	}
	push @groups, { access => \@access, name => $_->get_name(), id => $_->get_id() };
}

$template->param( 'groups' => \@groups );

my $script_dir = $ENV{SCRIPT_NAME};
$script_dir =~ s/\/[\w|\d|.]+$//;
$template->param( script     => $ENV{SCRIPT_NAME} );
$template->param( script_dir => $script_dir );
$template->param( pid        => $parent_id );
$template->param( lang_name  => $G->get_lang_name() );

print $template->output();

exit 0;

=cut
