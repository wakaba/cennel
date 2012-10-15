package Cennel::Loader::OperationStatus;
use strict;
use warnings;
use Dongry::Type;

sub new_from_dbreg_and_operation {
    return bless {dbreg => $_[1], operation => $_[2]}, $_[0];
}

sub dbreg {
    return $_[0]->{dbreg};
}

sub operation {
    return $_[0]->{operation};
}

sub load_statuses {
    my $self = shift;
    my $ops_db = $self->dbreg->load('cennelops');
    $ops_db->select(
        'operation_unit',
        {operation_id => $self->operation->operation_id},
    )->each(sub {
        $self->{operation_unit}->{$_->{operation_unit_id}} = $_;
    });
}

sub load_hosts {
    my $self = shift;
    my $defs_db = $self->dbreg->load('cennel');
    my $host_ids = [grep { $_ } map { $_->{host_id} } values %{$self->{operation_unit}}];
    return unless @$host_ids;
    $defs_db->select(
        'host',
        {host_id => {-in => $host_ids}},
    )->each_as_row(sub {
        $self->{host}->{$_->get('host_id')} = $_;
    });
}

sub as_jsonable {
    my $self = shift;
    $self->load_statuses;
    $self->load_hosts;

    my $op = $self->operation;

    return {
        repository => {
            id => $op->repository_id,
            url => $op->repository_url,
            branch => $op->repository_branch,
            sha => $op->repository_sha,
        },
        operation => {
            status => $op->status,
            data => $op->data,
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
        units => {
            map {
                my $v = $self->{operation_unit}->{$_};
                ($_ => +{
                    host => {
                        host_id => $v->{host_id},
                        name => $self->{host}->{$v->{host_id}} ? $self->{host}->{$v->{host_id}}->get('name') : undef,
                    },
                    status => $v->{status},
                    data => Dongry::Type->parse('text', $v->{data}),
                    scheduled_timestamp => $v->{scheduled_timestamp},
                    start_timestamp => $v->{start_timestamp},
                    end_timestamp => $v->{end_timestamp},
                });
            } keys %{$self->{operation_unit} or {}},
        },
    };
}

1;
