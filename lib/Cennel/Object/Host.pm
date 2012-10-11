package Cennel::Object::Host;
use strict;
use warnings;

sub new_from_row {
    return bless {host_row => $_[1]}, $_[0];
}

sub host_id {
    return $_[0]->{host_row}->get('host_id');
}

sub host_name {
    return $_[0]->{host_row}->get('name');
}

1;
