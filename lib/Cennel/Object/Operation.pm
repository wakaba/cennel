package Cennel::Object::Operation;
use strict;
use warnings;

sub new_from_rows {
    my ($class, %args) = @_;
    return bless {
        operation_row => $args{operation_row},
        repository_row => $args{repository_row},
    }, $class;
}

sub operaton_row {
    return $_[0]->{operation_row};
}

sub repository_row {
    return $_[0]->{repository_row} || die "|repository_row| is not set";
}

sub operation_id {
    return $_[0]->operation_row->get('operation_id');
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

sub task_name {
    return $_[0]->operation_row->get('task_name');
}

1;
