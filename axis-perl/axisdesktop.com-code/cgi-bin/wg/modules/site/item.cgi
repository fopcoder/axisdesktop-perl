#!/usr/bin/perl

use strict;
use lib $ENV{'DOCUMENT_ROOT'} . '/../lib';
use lib $ENV{'DOCUMENT_ROOT'} . '/lib';
use lib './lib';
use CGI::Minimal;
use JSON;
use HellFire::DataBase;
use HellFire::Guard;
use HellFire::Config;
use HellFire::Response;
use HellFire::Site::ItemDAO;

my $INI = new HellFire::Config();

my $B   = new HellFire::DataBase( $INI );
my $dbh = $B->connect();
my $q   = new CGI::Minimal;

my $G = new HellFire::Guard( $dbh, $q, $INI );
$G->check_session();

my $R = new HellFire::Response;
my $J = new JSON;
print $R->header( 'Content-Type' => 'text/x-json;charset=utf-8' );

my $parent_id = $q->param( 'parent_id' ) || $q->param( 'pid' ) || 0;
my $id        = $q->param( 'id' )        || 0;
my $action    = $q->param( 'action' )    || '';

#---------------------------------------------------------------

if( $action eq 'site_items_list' ) {
	my $C = new HellFire::Site::ItemDAO( $dbh, $G );

	my $parent_id = $q->param( 'pid' )   || 0;
	my $order_by  = $q->param( 'sort' )  || 'ordering';
	my $direction = $q->param( 'dir' )   || 'desc';
	my $start     = $q->param( 'start' ) || 0;
	my $limit     = $q->param( 'limit' ) || 50;
	my $rowsc     = 0;

	my $eee = $C->get_grid(
		{
			parent_id       => $parent_id,
			order_id        => $order_by,
			order_direction => $direction,
			offset          => $start,
			limit           => $limit,
			count_all       => \$rowsc
		}
	);

	my $res;
	$res->{metaData} = {
		id              => "id",
		root            => "rows",
		totalProperty   => "totalCount",
		successProperty => "success",
		fields          => [ { name => "id" }, { name => "inserted" }, { name => "name" }, { name => "alias" }, { name => "owner" }, { name => "ordering" } ],
		sortInfo        => {
			field     => $order_by,
			direction => $direction
		}
	};
	$res->{totalCount} = $rowsc;
	$res->{rows}       = $eee;
	$res->{columns}    = [
		{ dataIndex => "id",       header => "labelID",       sortable => 'true', width => 40 },
		{ dataIndex => "inserted", header => "labelInserted", sortable => 'true' },
		{ dataIndex => "name",     header => "labelURL",      sortable => 'true' },
		{ dataIndex => "alias",    header => "labelAlias",    sortable => 'true' },
		{ dataIndex => "owner",    header => "labelOwner",    sortable => 'true' },
		{ dataIndex => "ordering", header => "#",             sortable => 'true', width => 40 }
	];

	print( $J->encode( $res ) );
	exit 0;
}

if( $action eq 'site_item_view' ) {
	require HellFire::Configuration::ItemDAO;
	require HellFire::Site::TemplateDAO;
	require HellFire::User::ItemDAO;

	my $I = new HellFire::Site::ItemDAO( $dbh, $G );
	$I->load( $id, { no_clean => 1 } );

	my $res = $I->to_template();

	my $U = new HellFire::User::ItemDAO( $dbh, $G );
	$U->load( $I->get_user_id() );
	$res->{owner} = $U->get_name() || $U->get_name();

	my $CO = new HellFire::Configuration::ItemDAO( $dbh, $G );
	$CO->load( $I->get_handler_id() );
	$res->{handler_alias} = $CO->get_alias( $G->get_lang_id() ) || $CO->get_name();

	my $TE = new HellFire::Site::TemplateDAO( $dbh, $G );
	$TE->load( $I->get_template_id() );
	$res->{template_alias} = $TE->get_alias( $G->get_lang_id() ) || $TE->get_name();

	my $S = new HellFire::Site::CategoryDAO( $dbh, $G );
	$S->load( $I->get_parent_id() );
	$res->{parent_name} = $S->get_name();

	my $prefix = $S->get_top_parent_id( $I->get_parent_id() );
	$prefix .= "/c/" . $I->get_parent_id();

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
			width     => '100%'
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
			width     => '100%'
		},
		items => []
	};

	foreach ( @$l ) {
		my $lang = {
			title      => $_->{alias},
			layout     => 'form',
			autoHeight => 1,
			defaults   => {
				width     => '100%',
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
				width     => '100%',
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

		push @{ $lang->{items} },
		  {
			xtype      => 'textfield',
			hidden     => 1,
			name       => 'content_' . $_->{id},
			autoHeight => 1,
			value      => $I->get_content( $_->{id} )
		  };

		my $path = $INI->template_dir . "/$prefix/" . $I->get_content( $_->{id} );
		my $c;
		if( $I->get_content( $_->{id} ) && open( FILE, $path ) ) {
			$c = join( '', <FILE> );
			close FILE;
		}

		$I->get_name() =~ /\.(\w+)$/;
		my $ext = $1;

		if( $ext =~ /htm/ ) {
			push @{ $tlang->{items} }, {
				xtype     => 'ckeditor',
				language  => $1,
				hideLabel => 1,
				name      => 'content_data_' . $_->{id},
				id        => 'content_data_' . $I->get_id() . '_' . $_->{id},

				#autoHeight => 1,
				CKConfig => { customConfig => '/cgi-bin/wg/modules/site/template/js/ck_config.js' },
				value    => $c
			};
		}
		else {
			push @{ $tlang->{items} }, {
				xtype     => 'uxCodeMirrorPanel',
				language  => $1,
				parser    => $1,
				hideLabel => 1,
				name      => 'content_data_' . $_->{id},
				id        => 'content_data_' . $I->get_id() . '_' . $_->{id},

				#autoHeight => 1,
				value => $c
			};
		}

		push @{ $l10n->{items} }, $lang;
		push @{ $tpl->{items} },  $tlang;
	}

	$res->{l10n} = $l10n;
	$res->{tpl}  = $tpl;

	my @items_flags;

	my $ff = $B->get_set_values( 'site_items', 'flags' );
	foreach ( @$ff ) {
		next if( $_ eq 'DELETED' );
		push @items_flags,
		  {
			xtype      => 'checkbox',
			fieldLabel => 'FLAG_' . $_,
			name       => 'site_flag',
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

if( $action eq 'site_item_access_list' ) {
	my $I = new HellFire::Site::ItemDAO( $dbh, $G );
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

if( $action eq 'site_item_add' ) {
	if( $q->param( 'parent_id' ) && $q->param( 'name' ) ) {
		my $I = new HellFire::Site::ItemDAO( $dbh, $G );
		$I->set_parent_id( $q->param( 'parent_id' ) );
		$I->set_name( $q->param( 'name' ) );
		$I->add();

		my $o;
		if( $I->get_id() ) {
			$o->{success} = 'true';
		}
		else {
			$o->{success} = 'false';
		}
	}
	else {
		my $o;
		$o->{success} = 'false';
		print( $J->encode( $o ) );
	}

	exit 0;
}

if( $action eq 'site_item_copy' ) {
	foreach ( split( /,/, $q->param( 'ids' ) ) ) {
		my $I = new HellFire::Site::ItemDAO( $dbh, $G );
		$I->load( $_ );
		$I->copy();
	}

	my $o;
	$o->{success} = 1;

	print( $J->encode( $o ) );
	exit 0;
}

if( $action eq 'site_item_delete' ) {
	if( $q->param( 'id' ) ) {
		foreach ( split( /,/, $q->param( 'id' ) ) ) {
			my $I = new HellFire::Site::ItemDAO( $dbh, $G );
			$I->load( $_ );
			$I->destroy();
		}
	}

	my $o;
	$o->{success} = 1;

	print( $J->encode( $o ) );
	exit 0;
}

if( $action eq 'site_item_ordering' && $q->param( 'src' ) && $q->param( 'dst' ) ) {
	my $J = new JSON;
	my $C = new HellFire::Site::ItemDAO( $dbh, $G );

	if( $parent_id ) {
		$C->set_parent_id( $parent_id );
		$C->ordering( $q->param( 'src' ), $q->param( 'dst' ) );
		warn '111111';
	}

	$G->header( -type => "text/x-json" );
	print( $J->encode( { success => 1 } ) );
	exit 0;
}

if( $action eq 'site_item_update' && $q->param( 'id' ) ) {
	my $I = new HellFire::Site::ItemDAO( $dbh, $G );

	my $publish = 0;

	foreach my $i ( $q->param() ) {
		if( $i eq 'site_flag' ) {
			foreach ( $q->param( 'site_flag' ) ) {
				$I->set_flag( $_ );
				if( $_ eq 'PUBLISH' ) {
					$publish = 1;
				}
			}
		}
		elsif( $i =~ /alias_(\d+)/ ) {
			$I->set_alias( $1, $q->param( $i ) );
		}
		elsif( $i =~ /title_(\d+)/ ) {
			$I->set_title( $1, $q->param( $i ) );
		}
		elsif( $i =~ /keywords_(\d+)/ ) {
			$I->set_keywords( $1, $q->param( $i ) );
		}
		elsif( $i =~ /description_(\d+)/ ) {
			$I->set_description( $1, $q->param( $i ) );
		}
		elsif( $i =~ /content_(\d+)/ ) {
			$I->set_content( $1, $q->param( $i ) );
		}
		elsif( $i =~ /content_data_(\d+)/ ) {
			$I->set_content_data( $1, $q->param( $i ) );
		}
		elsif( $i =~ /json_access/ ) {
			my $J    = new JSON;
			my $code = $J->decode( $q->param( 'json_access' ) );
			foreach my $j ( @$code ) {
				if( $j->{value} eq 'false' || $j->{value} == 0 ) {
					$dbh->do( 'delete from site_item_access where parent_id = ? and group_id = ? and action_id = ?', undef, $q->param( 'id' ), $j->{group_id}, $j->{action_id} );
				}
				if( $j->{value} eq 'true' || $j->{value} > 0 ) {
					$dbh->do( 'insert ignore into site_item_access(parent_id,group_id,action_id) values(?,?,?)', undef, $q->param( 'id' ), $j->{group_id}, $j->{action_id} );
				}
			}
		}
		else {
			my $sf = 'set_' . $i;
			$I->$sf( $q->param( $i ) ) if( $I->can( $sf ) );
		}
	}


	$I->save();
	
	require HellFire::DataType;
	my $T = new HellFire::DataType( $dbh );
	my $langs = $T->get_languages();
	push @$langs, { name => '', alias => '' };
	
	my $rand = int rand(100000000);
	`mkdir -p /tmp/$rand`;
	foreach ( @$langs ) {
		my $f   = $ENV{DOCUMENT_ROOT} . '/' . $_->{name} . $I->get_path();
		my $tf  = "/tmp/$rand/" . $I->get_name();
		my $dir = $f;
		$dir =~ s/\/$//;
		$dir =~ s/\/(\w|\.)+$//;

		my $url = "http://$ENV{HTTP_HOST}" . '/' . $_->{name} . $I->get_path();
		if( length( $I->get_path() ) > 3 ) {
			if( -f $f ) {
				`rm $f`;
				unless( $dir =~ /htdocs\/?$/ ) {
					`rmdir  $dir`;
				}
			}
			if( $publish ) {
				`wget -q $url -O $tf`;
				unless( $dir =~ /htdocs$/ ) {
					`mkdir -p $dir`;
				}
				`mv $tf $f`;
			}
		}
		`rm -f $tf`;
	}
	`rmdir  /tmp/$rand`;

	print( $J->encode( { success => 1 } ) );
	exit 0;
}

if( $action eq 'site_item_move' && $q->param( 'src' ) && $q->param( 'dst' ) ) {
	my $C = new HellFire::Site::ItemDAO( $dbh, $G );

	foreach ( split( /,/, $q->param( 'src' ) ) ) {
		$C->load( $_ );
		$C->move( $q->param( 'dst' ) );

	}

	print( $J->encode( { success => 1 } ) );
	exit 0;
}

if( $action eq 'site_item_files_list' ) {
	require HellFire::File::ItemDAO;

	my $I = new HellFire::Site::ItemDAO( $dbh, $G );
	$I->load( $id );

	my $F = new HellFire::File::ItemDAO( $dbh, $G );
	my $rows = $F->get_admin_files( $I, { with_size => 1, with_type_alias => 1 } );

	if( eval "require Image::Magick" ) {
		foreach ( @$rows ) {
			if(
				!-e $ENV{DOCUMENT_ROOT} . $_->{src} . '.prev'
				&& (   $F->get_extension( $_->{src} ) =~ /jpg/i
					|| $F->get_extension( $_->{src} ) =~ /jpeg/i
					|| $F->get_extension( $_->{src} ) =~ /png/i )
			  )
			{
				my $IM = new Image::Magick;
				$IM->read( $ENV{DOCUMENT_ROOT} . $_->{src} );
				$IM->Set( quality => 70 );
				$IM->Thumbnail( geometry => '40x40', );
				$IM->write( $ENV{DOCUMENT_ROOT} . $_->{src} . '.prev' );
				undef $IM;
			}
			if( -f $ENV{DOCUMENT_ROOT} . $_->{src} . '.prev' ) {
				$_->{preview} = $_->{src} . '.prev';
			}
		}
	}

	my $res;
	$res->{metaData} = {
		id              => "id",
		root            => "rows",
		totalProperty   => "totalCount",
		successProperty => "success",
		fields          => [
			{ name => "id" },
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
			field     => 'type_name_alias',
			direction => 'desc'
		}
	};
	$res->{totalCount} = scalar @$rows;
	$res->{rows}       = $rows;

	print( $J->encode( $res ) );
	exit 0;
}

if( $action eq 'site_item_file_type' ) {
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

if( $action eq 'site_item_add_file' ) {
	require HellFire::File::ItemDAO;

	print $R->header( 'Content-Type' => 'text/x-json;charset=utf-8' );

	my $res;

	foreach ( $q->param( 'fileupload' ) ) {
		if( $q->param( 'type_id' ) ) {
			my $File = new HellFire::File::ItemDAO( $dbh, $G );
			$File->set_item_id( $q->param( 'id' ) );
			$File->set_type_id( $q->param( 'type_id' ) );
			$File->set_prefix( 'site/item' );
			$File->set_parent_id( $File->find_by_prefix( $File->get_prefix() ) );
			my $f2;
			$f2 = $q->param_filename( 'fileupload' ) if( $q->can( 'param_filename' ) );
			$File->upload( $_, $f2 );
			$File->process( { overwrite => $q->param( 'overwrite' ) || 0 } );
			$res = { success => 1 };
		}
		else {
			$res = { success => 0, message => 'FAILED. No type' };
		}
	}

	print( $J->encode( $res ) );
	exit 0;
}

if( $action eq 'site_item_del_file' ) {
	require HellFire::File::ItemDAO;
	if( $q->param( 'fid' ) ) {
		foreach ( split( /,/, $q->param( 'fid' ) ) ) {
			my $File = new HellFire::File::ItemDAO( $dbh, $G );
			$File->load( $_ );
			$File->destroy();
		}
	}

	print( $J->encode( { success => 1 } ) );
	exit 0;
}

print( $J->encode( { success => 0 } ) );
exit 0;

