package Cennel::Object::Operation;
use strict;
use warnings;

sub new_from_rows {
    my ($class, %args) = @_;
    return bless {
        operation_row => $args{operation_row},
        repository_row => $args{repository_row},
        role_row => $args{role_row},
    }, $class;
}

sub operation_row {
    return $_[0]->{operation_row};
}

sub repository_row {
    if (@_ > 1) {
        $_[0]->{repository_row} = $_[1];
    }
    return $_[0]->{repository_row} || die "|repository_row| is not set";
}

sub role_row {
    if (@_ > 1) {
        $_[0]->{role_row} = $_[1];
    }
    return $_[0]->{role_row} || die "|role_row| is not set";
}

sub operation_id {
    return $_[0]->operation_row->get('operation_id');
}

sub repository_id {
    return $_[0]->operation_row->get('repository_id');
}

sub repository_url {
    return $_[0]->repository_row->get('url');
}

sub repository_branch {
    return $_[0]->operation_row->get('repository_branch');
}

sub repository_sha {
    return $_[0]->operation_row->get('repository_sha');
}

sub role_id {
    return $_[0]->operation_row->get('role_id');
}

sub role_name {
    return $_[0]->role_row->get('name');
}

sub task_name {
    return $_[0]->operation_row->get('task_name');
}

sub status {
    return $_[0]->operation_row->get('status');
}

sub data {
    return $_[0]->operation_row->get('data');
}

sub start_timestamp {
    return $_[0]->operation_row->get('start_timestamp');
}

sub end_timestamp {
    return $_[0]->operation_row->get('end_timestamp');
}

1;
