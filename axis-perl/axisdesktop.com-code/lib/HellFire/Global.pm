package HellFire::Global;

use strict;

my $singleton;

sub new {
    my $class = shift;
    my $self = {
        _domain => undef,
        _crumbs => []
    };

    $singleton ||= bless $self, $class;
}



1;
