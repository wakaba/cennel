package Cennel::Loader::Operation;
use strict;
use warnings;
use Cennel::Object::Operation;

sub new_from_dbreg_and_operation_id {
    return bless {dbreg => $_[1], operation_id => $_[2]}, $_[0];
}

sub dbreg {
    return $_[0]->{dbreg};
}

sub operation_id {
    return $_[0]->{operation_id};
}

sub operation {
    return $_[0]->{operation};
}

sub load_operation {
    my $self = shift;
    my $ops_db = $self->dbreg->load('cennelops');
    my $op_row = $ops_db->select('operation', {operation_id => $self->operation_id})->first_as_row
        or return;
    $self->{operation} = Cennel::Object::Operation->new_from_rows(
        operation_row => $op_row,
    );
}

sub load_repository {
    my $self = shift;
    my $defs_db = $self->dbreg->load('cennel');
    my $op = $self->operation or return;
    my $repo_row = $defs_db->select('repository', {repository_id => $op->repository_id})->first_as_row;
    $op->repository_row($repo_row) if $repo_row;
}

sub load_role {
    my $self = shift;
    my $defs_db = $self->dbreg->load('cennel');
    my $op = $self->operation or return;
    my $role_row = $defs_db->select('role', {role_id => $op->role_id})->first_as_row;
    $op->role_row($role_row) if $role_row;
}

1;
