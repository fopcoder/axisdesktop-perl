package HellFire::File::ItemDAO;

use strict;
use base qw(HellFire::File);
use HellFire::Settings::ItemDAO;
use HellFire::DataType;


sub new {
	my $class = shift;
	my $dbh   = shift;
	my $G     = shift;

	my $self = $class->SUPER::new();
	$self->{'_dbh'}   = $dbh;
	$self->{'_guard'} = $G;

	bless $self, $class;
	return $self;
}

sub ini {
	my $self = shift;
	return $self->{'_guard'}->ini;
}

sub load {
	my $self   = shift;
	my $id     = shift || $self->get_id() || 0;
	my $params = shift;

	$self->set_id( $id );

	my $query = 'select * from file_items where id = ?';
	my $h = $self->dbh->selectrow_hashref( $query, undef, $id );
	$self->flags_to_hash( $h );

	foreach my $i ( keys %$h ) {
		if( $i =~ /FLAG_(\w+)/ ) {

			#$self->set_flag( $1 );
		}
		else {

			#my $sf = "set_$i";
			#$self->$sf( $h->{$i} );
			my $e = '$self->set_' . $i . '("' . $h->{$i} . '")';
			eval( $e );
		}
	}

	if( $params->{with_size} ) {
		$self->set_size( $self->format_size() );
	}

	my $S = new HellFire::Settings::ItemDAO( $self->dbh, $self->guard );
	$S->load( $self->get_type() );
	$self->set_type_name( $S->get_name() );

	return 1;
}

sub upload {
	my $self     = shift;
	my $file     = shift;
	my $filename = shift;

	my $ext = $self->get_extension( $filename || $file );    # CGI<->CGI::Minimal hack
	$self->set_type( $ext );
	$self->set_name( $filename || substr( $file, rindex( $file, '/' ) + 1 ), { tr_name => 1 } );
	$self->set_tmp( "/tmp/" . ( int rand( 1000000000 ) ) . "." . $self->get_type() );

	if( open( F, ">" . $self->get_tmp() ) ) {
		if( $filename ) {
			print F $file;
		}
		else {
			my $buffer;
			while ( read( $file, $buffer, 1024 ) ) {
				print F $buffer;
			}
		}
		close( F );
	}
}

sub get_extension {
	my $self = shift;
	my $fn   = shift;

	return substr( $fn, rindex( $fn, '.' ) + 1 );
}

sub process {
	my $self   = shift;
	my $params = shift;

	require Image::Magick;
	require HellFire::Settings::FieldDAO;
	require HellFire::Settings::ValueDAO;

	my $dbh = $self->dbh();
	my $T   = new HellFire::DataType( $dbh );

	my $pp     = int( $self->get_item_id() / 1000 );
	my $prefix = $self->get_prefix();
	my $path   = $self->ini->store_dir . "/$prefix/" . $pp . '/' . $self->get_item_id();
	`mkdir -p $path`;

	my $file_dir_rel  = $self->ini->store_dir_rel() . "/$prefix/" . $pp . '/' . $self->get_item_id();
	my $file_name_rel = $file_dir_rel . '/' . $self->get_name();
	my $file_dir_abs  = $path;
	my $file_name_abs = $file_dir_abs . '/' . $self->get_name();

	$params->{overwrite} = ( $params->{overwrite} eq 'false' || !$params->{overwrite} ) ? 0 : 1;

	if( $params->{overwrite} ) {
		my $fid = $self->dbh->selectrow_array('select id from file_items where url = ? and parent_img = 0', undef, $file_name_rel );

		if( $fid )	{
			my $query = 'select id from file_items where parent_img = ? or id = ? order by id desc';
			my $sth   = $self->dbh->prepare( $query );
			$sth->execute( $fid, $fid );
			while ( my $h = $sth->fetchrow_hashref() ) {
				my $DF = new HellFire::File::ItemDAO( $self->dbh, $self->guard );
				$DF->load( $h->{id} );
				$DF->destroy();
			}
		}
	}

	my $query = 'select id from settings_categories where name = "file_types"';
	my $tid   = $dbh->selectrow_array( $query );

	my %ret;

	# load cuts types
	my $F = new HellFire::Settings::FieldDAO( $dbh, $self->guard );
	$F->set_parent_id( $tid );
	$F->load( $F->find( 'cut' ) );

	my $V = new HellFire::Settings::ValueDAO( $dbh, $self->guard );
	$V->set_item_id( $self->get_type_id() );
	$V->set_parent_id( $F->get_id() );
	$V->set_type_id( $F->get_type_id() );
	$V->load();

	my $itype = $V->get_value_id();
	unshift @$itype, $self->get_type_id();

	# load width field
	my $SF = new HellFire::Settings::FieldDAO( $dbh, $self->guard );
	$SF->set_parent_id( $tid );
	$SF->load( $SF->find( 'width' ) );

	# load height field
	my $SF2 = new HellFire::Settings::FieldDAO( $dbh, $self->guard );
	$SF2->set_parent_id( $tid );
	$SF2->load( $SF2->find( 'height' ) );

	# load watermark field
	my $SF3 = new HellFire::Settings::FieldDAO( $dbh, $self->guard );
	$SF3->set_parent_id( $tid );
	$SF3->load( $SF2->find( 'watermark' ) );

	# load proportion field
	my $PF = new HellFire::Settings::FieldDAO( $dbh, $self->guard );
	$PF->set_parent_id( $tid );
	$PF->load( $PF->find( 'proportion' ) );

	my $parent_img = 0;
	foreach ( @$itype ) {
		my $SI = new HellFire::Settings::ItemDAO( $dbh, $self->guard );
		$SI->load( $_ );

		my $W = new HellFire::Settings::ValueDAO( $dbh, $self->guard );
		$W->load( $SF, $SI );

		my $H = new HellFire::Settings::ValueDAO( $dbh, $self->guard );
		$H->load( $SF2, $SI );

		my $M = new HellFire::Settings::ValueDAO( $dbh, $self->guard );
		$M->load( $SF3, $SI );

		my $PV = new HellFire::Settings::ValueDAO( $dbh, $self->guard );
		$PV->load( $PF, $SI );

		my $w2 = $W->to_string()  || 10000000;
		my $h2 = $H->to_string()  || 10000000;
		my $p2 = $PV->to_string() || 0;

		my $Img = new Image::Magick();
		$Img->Read( $self->get_tmp() );
		
		if( $p2 ) {
			my $ih = $Img->Get( 'height' ) || 1;
			my $iw = $Img->Get( 'width' )  || 1;
			if( $iw / $ih > $p2 ) {
				my $d = ( $iw - $ih * $p2 ) / 2;
				$Img->Crop( geometry => $ih * $p2 . 'x' . $ih . '+' . $d . '+0' );
				#$Img->Thumbnail();
			}
			elsif( $iw / $ih < $p2 ) {
				my $d = ( $ih - $iw / $p2 ) / 2;
				$Img->Crop( geometry => $iw . 'x' . $iw / $p2 . '+0+' . $d );
				#$Img->Thumbnail();
			}
		}

		if( $Img->Get( 'height' ) > $h2 || $Img->Get( 'width' ) > $w2 ) {
			$Img->Resize( geometry => $w2 . 'x' . $h2 );
			#$Img->Thumbnail( geometry => $w2 . 'x' . $h2 );
		}

		my $WM;
		if( -s $ENV{DOCUMENT_ROOT} . $M->to_string() ) {
			$WM = new Image::Magick();
			$WM->Read( $ENV{DOCUMENT_ROOT} . $M->to_string() );
		}

		my $BgImg;
		if( $params->{fit_size} ) {
			my $bg = $params->{background} || 'white';
			$BgImg = new Image::Magick;
			$BgImg->Set( size => $w2 . 'x' . $h2 );
			$BgImg->ReadImage( 'xc:' . $bg );
			$BgImg->Composite( image => $Img, gravity => 'Center' );
		}
		
		unless( $self->get_ordering() ) {
			my $ord = $self->dbh->selectrow_array( 'select max(ordering) from file_items where item_id = ?', undef, $self->get_item_id() );
			$ord += 10;
			$self->set_ordering( $ord );
		}

		my $query = 'insert into file_items(name,parent_img,type,item_id,inserted,parent_id,user_id, ordering, url ) 
				values(?,?,?,?,now(),?,?,?,?)';
		$self->dbh->do( $query, undef, $self->get_name(), $parent_img, $_, $self->get_item_id(), $self->find_by_prefix( $self->get_prefix() ), $self->guard->get_user_id(), $self->get_ordering(), $file_name_rel.rand() );

		my $fid = $self->dbh->last_insert_id( undef, undef, undef, undef );
		$parent_img = $fid unless( $parent_img );
		
		unless( $params->{overwrite} )	{
			if( -f $file_name_abs )	{
				my $c = 0;
				my $fname = $self->get_name();
				while( -f $file_name_abs )	{
					last if( $c > 1000 );
					$c++;
					if( $fname =~ /_(\d+)(\.\w+)$/ )	{
						$fname =~ s/_(\d+)(\.\w+)$/_$c$2/;
					}
					else	{
						$fname =~ s/(\.\w+)$/_$c$1/;
					}

					$file_name_abs = $file_dir_abs.'/'.$fname;
				}
				$file_name_rel = $file_dir_rel.'/'.$fname;
				$self->set_name( $fname );
			}
		}

		if( $w2 == 10000000 && $h2 == 10000000 && ! $p2 ) {
			my $src = $self->get_tmp();
			`cp $src $file_name_abs`;
		}
		else {
			if( $BgImg ) {
				$BgImg->Thumbnail();
				$BgImg->Write( $file_name_abs );
			}
			else {
				if( $WM->Get( 'height' ) ) {
					$Img->Composite( image => $WM, gravity => 'northwest' );
				}
				$Img->Thumbnail();
				$Img->Write( $file_name_abs );
			}
		}

		$query = 'update file_items set name= ?, url = ? where id = ?';
		$self->dbh->do( $query, undef, $self->get_name(), $file_name_rel, $fid );
		undef $Img;
		undef $BgImg;
		undef $WM;

		$ret{$_} = $file_name_rel;
	}

	#unlink $self->get_tmp();
	return \%ret;
}

sub destroy {
	my $self = shift;

	my $query = 'select id from file_items where parent_img = ? and  parent_img > 0';
	my $sth   = $self->dbh->prepare( $query );
	$sth->execute( $self->get_id() );

	while ( my $id = $sth->fetchrow_array() ) {
		my $F = new HellFire::File::ItemDAO( $self->dbh, $self->guard );
		$F->load( $id );
		$F->destroy();
	}

	unlink $self->ini->document_root . $self->get_url();
	unlink $self->ini->document_root . $self->get_url() . '.prev';
	$self->dbh->do( 'delete from file_items where id = ?', undef, $self->get_id() );
}

sub find_by_prefix {
	my $self = shift;
	my $val = shift || '';

	my $query = 'select id from file_categories where prefix = ?';
	my $id = $self->{_dbh}->selectrow_array( $query, undef, $val );

	return $id;
}


## @method arrayref get_files_by_group( HellFie::OBJ obj, hashref params )
# @brief Return files of OBJ group by type
# @param obj HellFire::OBJ
# @param params hashref input params
# 			- with_group : list : shows only type group of selected file type
# 			- with_type : list : shows only selected type in group
#			- file_group_limit : int : limits groups per type
# @return arrayref of files by type
#
# @code
# my $I = new HellFire::Article::ItemDAO( $self->dbh, $G );
# $I->load( $_->{id}, { lang_id => 1 } );
# my $File = new HellFire::File::ItemDAO( $self->dbh, $G );
# my $gfs = $File->get_files_by_group( $I , { with_type => 'img_50x50, 13', with_group => 'logo' } );
#
# in template
#
# <TMPL_LOOP FILES_BY_GROUP>
# 	<TMPL_LOOP GROUP_FILES>
#		<TMPL_LOOP FILES>
#			<TMPL_VAR SRC>
#		</TMPL_LOOP>
#	</TMPL_LOOP>
# </TMPL_LOOP>
# @endcode


# my $File = new HellFire::File::ItemDAO( $self->dbh, $G );
#			my $gfs = $File->get_files_by_group( $I, $self->config->{ $G->get_path() }  );
sub get_files_by_group {
	my $self   = shift;
	my $obj    = shift;
	my $params = shift;

	my $T = new HellFire::DataType( $self->dbh );

	my $path;
	if( ref $obj eq 'HASH' ) {
		$path = lc( $obj->{obj} );
	}
	else {
		$path = lc( ref $obj );
	}
	$path =~ s/^hellfire:://g;
	$path =~ s/dao$//g;
	$path =~ s/::/\//g;

	my $pid = $self->find_by_prefix( $path );

	my %pairH;
	foreach ( keys %$params ) {
		if( $_ =~ /pair_file_(\w+)(@\d+)?/ ) {
			my $id   = $1;
			my $pref = $2;

			if( $id =~ /[A-Za-z]/ ) {
				$id = $T->find_file_type( $id );
			}

			if( $params->{$_} =~ /[A-Za-z]/ ) {
				$pairH{ $id . $pref } = $T->find_file_type( $params->{$_} );
			}
			else {
				$pairH{ $id . $pref } = $1;
			}
		}
	}

	my @group_id;
	$params->{with_file_groups} =~ s/\s+//g;

	foreach ( split( /,/, $params->{with_file_group} ) ) {
		my $id;

		if( $_ =~ /[A-Za-z]/ ) {
			$id = $T->find_file_type( $_ );
		}
		else {
			$id = $_;
		}

		push @group_id, $id if( $id );
	}

	my @type_id;
	$params->{with_type} =~ s/\s+//g;

	foreach ( split( /,/, $params->{with_type} ) ) {
		my $id;

		if( $_ =~ /[A-Za-z]/ ) {
			$id = $T->find_file_type( $_ );
		}
		else {
			$id = $_;
		}

		push @type_id, $id if( $id );
	}

	my $query = 'SELECT type, group_concat(id order by ordering ) id FROM file_items
					WHERE item_id = ? AND parent_id = ? AND parent_img = 0';
	$query .= ' and type in(' . join( ',', @group_id ) . ') ' if( scalar @group_id );
	$query .= ' GROUP BY type';

	my $sth = $self->dbh->prepare( $query );
	if( ref $obj eq 'HASH' ) {
		$sth->execute( $obj->{id}, $pid );
	}
	else {
		$sth->execute( $obj->get_id(), $pid );
	}
	my @groups;

	while ( my $h = $sth->fetchrow_hashref ) {
		my @files;
		my $S = new HellFire::Settings::ItemDAO( $self->dbh, $self->guard );
		$S->load( $h->{type} );

		#my %TYPE = ( $S->get_id() => $S );

		my $cnt = 0;
		foreach ( split /,/, $h->{id} ) {
			my @files2;
			my $sql;

			if( scalar @type_id ) {
				$sql = ' AND type IN(' . join( ',', @type_id ) . ') ';
			}

			$query = "
				( SELECT id, type FROM file_items WHERE id = ? )
				UNION
				( SELECT id, type FROM file_items WHERE parent_img = ? $sql )";
			my $sth2 = $self->dbh->prepare( $query );
			$sth2->execute( $_, $_ );

			my %idxH;
			my $idx = 0;
			while ( my $h2 = $sth2->fetchrow_hashref ) {
				my $F = new HellFire::File::ItemDAO( $self->dbh, $self->guard );
				$F->load( $h2->{id} );

				my $ff = $self->guard->ini->document_root . $F->get_url();
				$h2->{size} = $self->format_size( ( stat( $ff ) )[7] );

				$F->{_size} = $h2->{size};

				push @files2, $F->to_template( $params->{item} );
				$idxH{ $h2->{type} } = $idx++;
			}

			while ( ( my $k, my $v ) = each( %pairH ) ) {
				$k =~ s/@\d+//;
				if( defined $idxH{$v} ) {
					$files2[ $idxH{$k} ]->{pair_src} = $files2[ $idxH{$v} ]->{src};
				}
			}

			push @files, { id => $_, files => \@files2 };
			last if( $params->{file_group_limit} && ++$cnt >= $params->{file_group_limit} );
		}

		$h->{group_files}      = \@files;
		$h->{name}             = $S->get_name();
		$h->{ $S->get_name() } = 1;
		$h->{alias}            = $S->get_alias( $self->guard->get_lang_id() );

		push @groups, $h;

	}

	return \@groups;
}

sub get_admin_files {

	my $self   = shift;
	my $obj    = shift;
	my $params = shift;

	my $T = new HellFire::DataType( $self->dbh );

	my $path;
	if( ref $obj eq 'HASH' ) {
		$path = lc( $obj->{obj} );
	}
	else {
		$path = lc( ref $obj );
	}
	$path =~ s/^hellfire:://g;
	$path =~ s/dao$//g;
	$path =~ s/::/\//g;

	my $pid = $self->find_by_prefix( $path );

	my @files;

	my $query = 'select id from file_items where parent_img = 0 and item_id = ? and parent_id = ? order by type';
	my $sth   = $self->dbh->prepare( $query );
	if( ref $obj eq 'HASH' ) {
		$sth->execute( $obj->{id}, $pid );
	}
	else {
		$sth->execute( $obj->get_id(), $pid );
	}

	while ( my $h = $sth->fetchrow_hashref ) {
		my $F = new HellFire::File::ItemDAO( $self->dbh, $self->guard );
		$F->load( $h->{id}, $params );

		push @files, $F->to_template( $params );
	}

	return \@files;
}

sub set_size {
	my $self = shift;
	$self->{_size} = shift || 0;
	return $self->{_size};
}

sub set_alias {
	my $self = shift;
}

sub to_template {
	my $self   = shift;
	my $params = shift;

	my $ret = {};
	$ret->{id}                       = $self->get_id();
	#$ret->{href}                     = $self->get_url();
	$ret->{src}                      = $self->get_url();
	$ret->{parent_img}               = $self->get_parent_img();
	$ret->{item_id}                  = $self->get_item_id();
	$ret->{ordering}                 = $self->get_ordering();
	$ret->{type_name}                = $self->get_type_name();
	$ret->{inserted}                 = $self->get_inserted();
	$ret->{type}                     = $self->get_type();
	$ret->{size}                     = $self->{_size};
	$ret->{user_id}                  = $self->get_user_id();
	$ret->{ $self->get_type_name() } = 1;
	if( $params->{with_type_alias} ) {
		require HellFire::Settings::ItemDAO;
		my $S = new HellFire::Settings::ItemDAO( $self->dbh, $self->guard );
		$S->load( $self->get_type() );
		$ret->{type_alias}      = $S->get_alias( $self->guard->get_lang_id() );
		$ret->{type_name_alias} = $ret->{type_alias} . ' (' . $ret->{type_name} . ')';
	}
	
	$ret->{alt} = $params->{alias};
    $ret->{href} = $params->{href};

	return $ret;
}

sub get_parent_img {
	my $self = shift;
	return $self->{_parent_img} || 0;
}

sub set_parent_img {
	my $self = shift;
	$self->{_parent_img} = shift;
	return $self->{_parent_img};
}

sub get_type_name {
	my $self = shift;
	return $self->{_type_name} || '';
}

sub set_type_name {
	my $self = shift;
	$self->{_type_name} = shift;
	return $self->{_type_name};
}

return 1;
