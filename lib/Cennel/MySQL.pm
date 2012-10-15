package Cennel::MySQL;
use strict;
use warnings;

sub define_schema {
    my (undef, $dbreg) = @_;

    $dbreg->{Registry}->{cennel}->{schema} = {
        repository => {},
        role => {},
        host => {},
    };
    $dbreg->{Registry}->{cennelops}->{schema} = {
        operation => {},
    };
}

1;
