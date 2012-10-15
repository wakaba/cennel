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
        operation => {
            primary_keys => ['operation_id'],
        },
        operation_unit => {
            primary_keys => ['operation_unit_id'],
        },
        operation_unit_job => {},
    };
}

1;
