package CGI::SSI_M;
use strict;

use FindBin;

our $DEBUG = 0;

sub parse_args {
  my $self = shift;  # Not needed here
  my $str = shift;
  my $fix_case = 0 ;#((ref $self and exists $self->{fix_case}) ? $self->{fix_case} : $FIX_CASE);
  my @returns;

    pos($str) = 0;
  
  while (1) {
    next if $str =~ m/\G\s+/gc;  # Get rid of leading whitespace
    
    if ( $str =~ m/\G
     ([\w.-]+)\s*=\s*                         # the key
     (?:
      "([^\"\\]*  (?: \\.[^\"\\]* )* )"\s*    # quoted string, with possible whitespace inside,
      |                                       #  or
      '([^\'\\]*  (?: \\.[^\'\\]* )* )'\s*    # quoted string, with possible whitespace inside,
      |                                       #  or
      ([^\s>]*)\s*                            # anything else, without whitespace or >
     )/gcx ) {
      
      my ($key, $val) = ($1, $+);
      $val =~ s/\\(.)/$1/gs;
      push @returns, ($fix_case==1 ? uc($key) : $fix_case==-1 ? lc($key) : $key), $val;
      
    } elsif ( $str =~ m,\G/?([\w.-]+)\s*,gc ) {
      push @returns, ($fix_case==1 ? uc($1)   : $fix_case==-1 ? lc($1)   : $1  ), undef;
    } else {
      last;
    }
  }
  
  return @returns;
}

sub new {
	my($class,%args) = @_;
	my $self = bless { '_request' => $args{'request'} }, $class;

	$self->{'_handle'}        = undef;

	my $script_name = '';
	if(exists $ENV{'SCRIPT_NAME'}) {
		($script_name) = $ENV{'SCRIPT_NAME'} =~ /([^\/]+)$/;
	}

	$ENV{'DOCUMENT_ROOT'} ||= '';
	$self->{'_variables'}     = {
		DOCUMENT_URI    =>  ($args{'DOCUMENT_URI'} || $ENV{'SCRIPT_NAME'}),
		DOCUMENT_NAME   =>  ($args{'DOCUMENT_NAME'} || $script_name),
		DOCUMENT_ROOT   =>  ($args{'DOCUMENT_ROOT'} || $ENV{DOCUMENT_ROOT}),
	};

	$self->{'_config'}        = {
		errmsg  =>  ($args{'errmsg'}  || '[an error occurred while processing this directive]'),
		sizefmt =>  ($args{'sizefmt'} || 'abbrev'),
		timefmt =>  ($args{'timefmt'} ||  undef),
	};

	$self->{_max_recursions} = $args{MAX_RECURSIONS} || 100; # no "infinite" loops
		$self->{_recursions} = {};

	$self->{'_in_if'}     = 0;
	$self->{'_suspend'}   = [0];
	$self->{'_seen_true'} = [1];

	return $self;
}

sub request	{
  my $self = shift;
  return $self->{_request};
}

sub process {
	my($self,@shtml) = @_;
	my $processed = '';
	@shtml = split(/(<!--#.+?-->)/s,join '',@shtml);
	for my $token (@shtml) {
		if($token =~ /^<!--#(.+?)\s*-->$/s) {
			$processed .= $self->_process_ssi_text($self->_interp_vars($1));
		} else {
			next if $self->_suspended;
			$processed .= $token;
		}
	}
	return $processed;
}

sub _process_ssi_text {
    my($self,$text) = @_;

    return '' if($self->_suspended and $text !~ /^(?:if|else|elif|endif)\b/);

	# what's the first \S+?
	if($text !~ s/^(\S+)\s*//) {
		warn ref($self)." error: failed to find method name at beginning of string: '$text'.\n";
	    return $self->{'_config'}->{'errmsg'};
	}
    my $method = $1;
    return $self->$method( $self->parse_args($text) );
}

sub _interp_vars {
    local $^W = 0;
    my($self,$text) = @_;
    my($a,$b,$c) = ('','','');
    $text =~ s{ (^|[^\\]) (\\\\)* \$(?:\{)?(\w+)(?:\})? }
              {($a,$b,$c)=($1,$2,$3); $a . substr($b,length($b)/2) . $self->_echo($c) }exg;
    return $text;
}

sub _echo {
    my($self,$key,$var) = @_;
    $var = $key if @_ == 2;

    return $self->{'_variables'}->{$var} if exists $self->{'_variables'}->{$var};
    return $ENV{$var} if exists $ENV{$var};
    return $var;
}

#
# ssi directive methods
#

sub config {
    my($self,$type,$value) = @_;
    if($type =~ /^timefmt$/i) {
		$self->{'_config'}->{'timefmt'} = $value;
    } elsif($type =~ /^sizefmt$/i) {
		if(lc $value eq 'abbrev') {
		    $self->{'_config'}->{'sizefmt'} = 'abbrev';
		} elsif(lc $value eq 'bytes') {
		    $self->{'_config'}->{'sizefmt'} = 'bytes';
		} else {
			warn ref($self)." error: value for sizefmt is '$value'. It must be 'abbrev' or 'bytes'.\n";
		    return $self->{'_config'}->{'errmsg'};
		}
    } elsif($type =~ /^errmsg$/i) {
		$self->{'_config'}->{'errmsg'} = $value;
    } else {
		warn ref($self)." error: arg to config is '$type'. It must be one of: 'timefmt', 'sizefmt', or 'errmsg'.\n";
		return $self->{'_config'}->{'errmsg'};
    }
    return '';
}

sub set {
    my($self,%args) = @_;
    if(scalar keys %args > 1) {
		$self->{'_variables'}->{$args{'var'}} = $args{'value'};
    } else { # var => value notation
		my($var,$value) = %args;
		$self->{'_variables'}->{$var} = $value;
    }
    return '';
}

sub echo {
    my($self,$key,$var) = @_;
    $var = $key if @_ == 2;

    return $self->{'_variables'}->{$var} if exists $self->{'_variables'}->{$var};
    return $ENV{$var} if exists $ENV{$var};
    return '';
}

sub printenv {
    #my $self = shift;
    return join "\n",map {"$_=$ENV{$_}"} keys %ENV;
}

sub include {
	$DEBUG and do { local $" = "','"; warn "DEBUG: include('@_')\n" };
    my($self,$type,$filename) = @_;
    if(lc $type eq 'file') {
		return $self->_include_file($filename);
    } elsif(lc $type eq 'virtual') {
		return $self->_include_virtual($filename);
    } else {
		warn ref($self)." error: arg to include is '$type'. It must be one of: 'file' or 'virtual'.\n";
		return $self->{'_config'}->{'errmsg'};
    }
}

sub _include_file {
	$DEBUG and do { local $" = "','"; warn "DEBUG: _include_file('@_')\n" };
	my($self,$filename) = @_;

	$filename = $self->{'_variables'}->{'DOCUMENT_ROOT'}.'/'.$filename unless -e $filename;

	if(++$self->{_recursions}->{$filename} >= $self->{_max_recursions}) {
		warn ref($self)." error: the maximum number of 'include file' recursions has been exceeded for '$filename'.\n";
		return $self->{'_config'}->{'errmsg'};
	}

	my $fh = do { local *STDIN };
	open($fh,$filename) or do {
		warn ref($self)." error: failed to open file ($filename): $!\n";
		return $self->{'_config'}->{'errmsg'};
	};

	return $self->process(join '',<$fh>);
}

sub _include_virtual {
	$DEBUG and do { local $" = "','"; warn "DEBUG: _include_virtual('@_')\n" };
    my($self,$filename) = @_;

    if($filename =~ m|^/(.+)|) { # could be on the local server: absolute filename, relative to ., relative to $ENV{DOCUMENT_ROOT}
		my $file = $1;
		if(-e '/'.$file) { # back to the original
			$file = '/'.$file;
		} elsif(-e $self->{'_variables'}->{'DOCUMENT_ROOT'}.'/'.$file ) {
			$file = $self->{'_variables'}->{'DOCUMENT_ROOT'}.'/'.$file;
		} elsif(-e $FindBin::Bin.'/'.$file ) {
			$file = $FindBin::Bin.'/'.$file;
		}
		return $self->_include_file($file) if -e $file;
    }

	if(++$self->{_recursions}->{$filename} >= $self->{_max_recursions}) {
		#warn ref($self)." error: the maximum number of 'include virtual' recursions has been exceeded for '$url'.\n";
		warn ref($self)." error: the maximum number of 'include virtual' recursions has been exceeded for '$filename'.\n";
	    return $self->{'_config'}->{'errmsg'};
	}

	my $res;
	if( $self->request )	{
		require HellFire::Request;
		my $R = new HellFire::Request( $self->request->dbh, $self->request->guard, $self->request->q );
		return $R->request( $filename )->content();
	}
	else	{
	  warn 'CGI_SSI => no request';
	}

	#unless( $res ) {
	unless( $res->content ) {
	   warn ref($self)." error: failed to get('$filename'): \n";
		#return $self->{_config}->{errmsg};
		return $res->content( $self->{_config}->{errmsg} );
	}

	#return $res->content;
}

sub _test {
    my($self,$test) = @_;
    my $retval = eval($test);
    return undef if $@;
    return defined $retval ? $retval : 0;
}

sub _entering_if {
    my $self = shift;
    $self->{'_in_if'}++;
    $self->{'_suspend'}->[$self->{'_in_if'}] = $self->{'_suspend'}->[$self->{'_in_if'} - 1];
    $self->{'_seen_true'}->[$self->{'_in_if'}] = 0;
}

sub _seen_true {
    my $self = shift;
    return $self->{'_seen_true'}->[$self->{'_in_if'}];
}

sub _suspended {
    my $self = shift;
    return $self->{'_suspend'}->[$self->{'_in_if'}];
}

sub _leaving_if {
    my $self = shift;
    $self->{'_in_if'}-- if $self->{'_in_if'};
}

sub _true {
    my $self = shift;
    return $self->{'_seen_true'}->[$self->{'_in_if'}]++;
}

sub _suspend {
    my $self = shift;
    $self->{'_suspend'}->[$self->{'_in_if'}]++;
}

sub _resume {
    my $self = shift;
    $self->{'_suspend'}->[$self->{'_in_if'}]--
		if $self->{'_suspend'}->[$self->{'_in_if'}];
}

sub _in_if {
    my $self = shift;
    return $self->{'_in_if'};
}

sub if {
    my($self,$expr,$test) = @_;
    $expr = $test if @_ == 3;
    $self->_entering_if();
    if($self->_test($expr)) {
		$self->_true();
    } else {
		$self->_suspend();
    }
    return '';
}

sub elif {
    my($self,$expr,$test) = @_;
    die "Incorrect use of elif ssi directive: no preceeding 'if'." unless $self->_in_if();
    $expr = $test if @_ == 3;
    if(! $self->_seen_true() and $self->_test($expr)) {
		$self->_true();
		$self->_resume();
    } else {
		$self->_suspend() unless $self->_suspended();
    }
    return '';
}

sub else {
    my $self = shift;
    die "Incorrect use of else ssi directive: no preceeding 'if'." unless $self->_in_if();
    unless($self->_seen_true()) {
		$self->_resume();
    } else {
		$self->_suspend();
    }
    return '';
}

sub endif {
    my $self = shift;
    die "Incorrect use of endif ssi directive: no preceeding 'if'." unless $self->_in_if();
    $self->_leaving_if();
#    $self->_resume() if $self->_suspended();
    return '';
}

1;

__END__

