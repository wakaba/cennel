package Cennel::Object::Role;
use strict;
use warnings;

sub new_from_row {
    return bless {role_row => $_[1]}, $_[0];
}

sub role_name {
    return $_[0]->{role_row}->get('name');
}

1;
