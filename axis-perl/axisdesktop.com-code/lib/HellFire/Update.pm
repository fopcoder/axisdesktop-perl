package HellFire::Update;

use strict;
use Config::Tiny;

sub new {
	my $class = shift;
	my $dbh   = shift;
	my $G     = shift;

	my $self = {};
	$self->{_dbh}   = $dbh;
	$self->{_guard} = $G;
	$self->{_rnd}   = int rand 100000000;

	bless $self, $class;
	return $self;
}

sub dbh {
	my $self = shift;
	return $self->{_dbh};
}

sub guard {
	my $self = shift;
	return $self->{_guard};
}

sub ini {
	my $self = shift;
	return $self->{_guard}->ini;
}

sub get_modules {
	my $self = shift;

	`mkdir /tmp/$$self{_rnd}`;
	`wget http://javahosting.com.ua/repo/packages2.ini -O /tmp/$$self{_rnd}/packages2.ini`;
	my @arr;
	my $Config = Config::Tiny->read( "/tmp/$$self{_rnd}/packages2.ini" );
	foreach ( keys %$Config ) {
		my $v = $self->{_dbh}->selectrow_array( 'select version from configuration where name = ?', undef, $_ );
		my $h;
		$h->{name}    = $_;
		$h->{version} = $Config->{$_}->{version};
		$h->{file}    = $Config->{$_}->{file};
		$h->{update}  = 1 if( $self->get_int_version( $v ) != $self->get_int_version( $h->{version} ) );
		push @arr, $h;
	}

	@arr = sort { $a->{name} cmp $b->{name} } @arr;

	return \@arr;
	`rm -rf /tmp/$$self{_rnd}` if( $$self{_rnd} );
}

sub update_module {
	my $self = shift;
	my $q    = shift;

	if( $self->guard->is_administrator() ) {
		foreach ( $q->param( 'uname' ) ) {
			my $name = $_;
			my $file = $q->param( "ufile_$name" ) || '-';

			$self->setup_module( $name, $file );
		}
	}
}

sub setup_module {
	my $self    = shift;
	my $name    = shift;
	my $file    = shift;
	my $version = shift;

	`mkdir -p /tmp/$$self{_rnd}`;

	#`rm /tmp/$$self{_rnd}/$file`;
	#`rm -rf /tmp/$$self{_rnd}/$name`;
	`wget http://javahosting.com.ua/repo/$file -O /tmp/$$self{_rnd}/$file -o /tmp/$$self{_rnd}/hellog`;
	`cd /tmp/$$self{_rnd} && tar -zxvf $file`;
	my $lib_dir      = $self->ini->lib_dir();
	my $conf_dir     = $self->ini->conf_dir();
	my $module_dir   = $self->ini->modules_dir_abs();
	my $template_dir = $self->ini->template_dir();
	my $res_dir      = $self->ini->res_dir_abs();

	`cp -R /tmp/$$self{_rnd}/$name/lib/* $lib_dir`          if( -d "/tmp/$$self{_rnd}/$name/lib" );
	`cp -R /tmp/$$self{_rnd}/$name/module/* $module_dir`    if( -d "/tmp/$$self{_rnd}/$name/module" );
	`cp -R /tmp/$$self{_rnd}/$name/module/.ht* $module_dir` if( -e "/tmp/$$self{_rnd}/$name/module" );
	`cp -R /tmp/$$self{_rnd}/$name/res/* $res_dir`          if( -d "/tmp/$$self{_rnd}/$name/res" );

	`mkdir -p $template_dir/$name`;
	`cp -R /tmp/$$self{_rnd}/$name/template/* $template_dir/$name` if( -e "/tmp/$$self{_rnd}/$name/template" );

	if( -e "/tmp/$$self{_rnd}/$name/conf" ) {
		`cp -R /tmp/$$self{_rnd}/$name/conf/*.ini.dist $conf_dir`;
		my $src;
		$src = scalar( join( '', glob "/tmp/$$self{_rnd}/$name/conf/*.ini.dist" ) );

		my $dst = $src;
		$dst =~ s/\.dist//;
		$dst = substr( $dst, rindex( $dst, '/' ) + 1 );

		$dst = $conf_dir . '/' . $dst;
		$self->setup_ini( $src, $dst );
	}

	my @dsn = split( /:/, $self->ini->obj->{default_connection}->{dsn} );
	my $db_host = $dsn[3];
	my $db_name = $dsn[2];
	my $db_user = $self->ini->obj->{default_connection}->{user};
	my $db_pass = $self->ini->obj->{default_connection}->{password};
	$db_pass = $self->dbh->quote($db_pass);
	my $db_client = qx(which mysql);
	$db_client =~ s/\s+//g;
	my $db_query = "/tmp/$$self{_rnd}/$name/setup/pre.sql";
	
	if( -f $db_query )	{
		`$db_client -f -h $db_host -u $db_user -p$db_pass $db_name < $db_query`;
	}

	if( -e "/tmp/$$self{_rnd}/$name/setup" ) {
		require "/tmp/$$self{_rnd}/$name/setup/Pre.pm";
		Pre::run( $self->dbh, $self->ini );
		require "/tmp/$$self{_rnd}/$name/setup/Post.pm";
		Post::run( $self->dbh, $self->ini, { version => $version } );
	}
	
	$db_query = "/tmp/$$self{_rnd}/$name/setup/post.sql";
	if( -f $db_query )	{
		`$db_client -f -h $db_host -u $db_user -p$db_pass $db_name < $db_query`;
	}

	`rm -rf /tmp/$$self{_rnd}` if( $$self{_rnd} );
}

sub setup_ini {
	my $self = shift;
	my $src  = shift;
	my $dst  = shift;

	my $S = Config::Tiny->read( $src );
	my $D;

	if( -e $dst ) {
		$D = Config::Tiny->read( $dst );
	}
	else {
		$D = Config::Tiny->new();
	}

	foreach my $a ( keys %$S ) {
		foreach my $b ( keys %{ $S->{$a} } ) {
			$D->{$a}->{$b} = $S->{$a}->{$b} unless( $D->{$a}->{$b} );
		}
	}
	$D->write( $dst );
}

sub get_int_version {
	my $self = shift;
	my $v    = shift;
	$v =~ /(\d+)\.(\d+)\.(\d+)/;
	my $o = $1 * 1000 + $2 * 1000 + $3;
	return $o || 0;
}

return 1;
