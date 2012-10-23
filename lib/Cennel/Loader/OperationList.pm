package Cennel::Loader::OperationList;
use strict;
use warnings;
use Cennel::Object::Operation;

sub new_from_dbreg {
    return bless {dbreg => $_[1]}, $_[0];
}

sub dbreg {
    return $_[0]->{dbreg};
}

sub per_page {
    if (@_ > 1) {
        $_[0]->{per_page} = $_[1];
    }
    return 100;
}

sub load_recent_operations {
    my $self = shift;

    my $ops_db = $self->dbreg->load('cennelops');
    my $op_rows = $ops_db->execute(
        'SELECT * FROM `operation` ORDER BY `start_timestamp` DESC LIMIT :lim',
        {lim => $self->per_page},
        table_name => 'operation',
        fields => [qw(
            operation_id repository_id repository_branch repository_sha
            role_id task_name status start_timestamp end_timestamp
        )],
    )->all_as_rows;
    return unless @$op_rows;

    my $defs_db = $self->dbreg->load('cennel');
    my $repo_rows = $defs_db->select(
        'repository',
        {repository_id => {-in => $op_rows->map(sub { $_->get('repository_id') })->uniq_by_key(sub { $_ })}},
    )->all_as_rows->as_hashref_by_key(sub { $_->get('repository_id') });
    my $role_rows = $defs_db->select(
        'role',
        {role_id => {-in => $op_rows->map(sub { $_->get('role_id') })->uniq_by_key(sub { $_ })}},
    )->all_as_rows->as_hashref_by_key(sub { $_->get('role_id') });

    $self->{operations} = $op_rows->map(sub {
        return Cennel::Object::Operation->new_from_rows(
            operation_row => $_,
            repository_row => $repo_rows->{$_->get('repository_id')},
            role_row => $role_rows->{$_->get('role_id')},
        );
    });
}

sub as_jsonable {
    my $self = shift;
    return [
        map {
            my $op = $_;
            +{
                repository => {
                    id => $op->repository_id,
                    url => $op->repository_url,
                    branch => $op->repository_branch,
                    sha => $op->repository_sha,
                },
                operation => {
                    status => $op->status,
                    #data => $op->data,
                    start_timestamp => $op->start_timestamp,
                    end_timestamp => $op->end_timestamp,
                },
                role => {
                    id => $op->role_id,
                    name => $op->role_name,
                },
                task => {
                    name => $op->task_name,
                },
            };
        } @{$self->{operations} or []},
    ];
}

1;
