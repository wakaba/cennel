package Cennel::Action::RunOperationUnit;
use strict;
use warnings;
use AnyEvent;
use Dongry::Type;
use Cennel::Defs::Statuses;
use Cennel::Git::Repository;
use Cennel::Object::Operation;
use Cennel::Object::Host;
use Cennel::Object::Role;

sub new_from_dbreg_and_cached_repo_set_d_and_job_values {
    return bless {
        dbreg => $_[1],
        cached_repo_set_d => $_[2],
        operation_unit_job_values => $_[3],
        log => [],
    }, $_[0];
}

sub dbreg {
    return $_[0]->{dbreg};
}

sub cached_repo_set_d {
    return $_[0]->{cached_repo_set_d};
}

sub operation_unit_job_values {
    return $_[0]->{operation_unit_job_values};
}

sub operation_unit_id {
    return $_[0]->{operation_unit_id};
}

sub operation {
    return $_[0]->{operation};
}

sub role {
    return $_[0]->{role};
}

sub host {
    return $_[0]->{host};
}

sub task_name {
    return $_[0]->operation->task_name;
}

sub onmessage {
    if (@_ > 1) {
        $_[0]->{onmessage} = $_[1];
    }
    return $_[0]->{onmessage} || sub { };
}

sub run_as_cv {
    my $self = shift;
    my $cv = AE::cv;
    $self->open_record_as_cv->cb(sub {
        my $result = $_[0]->recv;
        unless ($result->{failed}) {
            $self->check_preconditions_as_cv->cb(sub {
                my $result = $_[0]->recv;
                unless ($result->{failed}) {
                    $self->run_action_as_cv->cb(sub {
                        my $result = $_[0]->recv;
                        $self->close_record_as_cv($result)->cb(sub {
                            $cv->send($result);
                        });
                    });
                } else {
                    $self->close_record_as_cv($result)->cb(sub {
                        $cv->send($result);
                    });
                }
            });
        } else {
            $self->close_record_as_cv($result)->cb(sub {
                $cv->send($result);
            });
        }
    });
    return $cv;
}

sub open_record_as_cv {
    my $self = shift;
    my $cv = AE::cv;

    my $job_values = $self->operation_unit_job_values;
    
    my $defs_db = $self->dbreg->load('cennel');
    my $ops_db = $self->dbreg->load('cennelops');

    my $operation_unit_id = $job_values->{operation_unit_id};
    $self->{operation_unit_id} = $operation_unit_id;
    my $unit_row = $ops_db->select('operation_unit', {operation_unit_id => $operation_unit_id})->first_as_row;
    my $op_row = $ops_db->select('operation', {operation_id => $unit_row->get('operation_id')})->first_as_row;
    my $host_id = $unit_row->get('host_id');
    my $host_row = $host_id ? $defs_db->select('host', {host_id => $host_id})->first_as_row : undef;
    my $role_row = $defs_db->select('role', {role_id => $op_row->get('role_id')})->first_as_row;
    my $repo_row = $defs_db->select('repository', {repository_id => $op_row->get('repository_id')})->first_as_row;
    
    $ops_db->execute(
        'UPDATE `operation_unit`
             SET status = ?,
                 data = CONCAT(data, :data), 
                 start_timestamp = ?
             WHERE operation_unit_id = ?',
        {
            status => OPERATION_UNIT_STATUS_STARTED,
            data => Dongry::Type->serialize('text', sprintf "[%s] operation unit started\n", scalar gmtime),
            start_timestamp => time,
            operation_unit_id => $operation_unit_id,
        },
    );

    unless ($unit_row and $op_row and (not $host_id or $host_row) and $role_row and $repo_row) {
        push @{$self->{log}}, sprintf "[%s] data incomplete\n", scalar gmtime;
        $cv->send({failed => 1, retry => 1, phase => 'open_record'});
        return;
    }

    $self->{operation} = Cennel::Object::Operation->new_from_rows(
        operation_row => $op_row,
        repository_row => $repo_row,
    );
    $self->{role} = Cennel::Object::Role->new_from_row($role_row);
    $self->{host} = Cennel::Object::Host->new_from_row($host_row) if $host_row;
    
    $cv->send({});
    return $cv;
}

sub check_preconditions_as_cv {
    my $self = shift;
    my $cv = AE::cv;

    my $task_name = $self->task_name;
    if ($task_name eq 'end-operation') {
        if ($self->dbreg->load('cennelops')->select(
            'operation_unit',
            {
                operation_id => $self->operation->operation_id,
                status => {-not_in => [
                    OPERATION_UNIT_STATUS_FAILED,
                    OPERATION_UNIT_STATUS_SUCCEEDED,
                ]},
            },
            field => 'operation_unit_id',
            limit => 1,
        )->first) {
            $cv->send({failed => 1, retry => 1, phase => 'check_preconditions'});
            return $cv;
        }
    }

    $cv->send({});
    return $cv;
}

sub run_action_as_cv {
    my $self = shift;
    my $repo = Cennel::Git::Repository->new_from_operation_and_cached_repo_set_d(
        $self->operation,
        $self->cached_repo_set_d,
    );
    my $onmessage = $self->onmessage;
    $repo->onmessage(sub {
        push @{$self->{log}}, $_[0];
        $onmessage->($_[0]);
    });
    my $cv = AE::cv;
    my $task_name = $self->task_name;
    if ($task_name eq 'end-operation') {
        require Cennel::Action::EndOperation;
        my $action = Cennel::Action::EndOperation->new_from_dbreg_and_operation($self->dbreg, $self->operation);
        $action->run_as_cv(sub {
            $cv->send({});
        });
    } else {
        $repo->run_repo_command_as_cv($task_name, $self->role->role_name, $self->host ? $self->host->host_name : '', $self->task_name)->cb(sub {
            if ($_[0]->recv->[0]) {
                $cv->send({failed => 1, retry => 0, phase => 'run_action'});
            } else {
                $cv->send({});
            }
        });
    }
    return $cv;
}

sub close_record_as_cv {
    my ($self, $result) = @_;
    my $status = $result->{failed}
        ? $result->{phase} eq 'check_preconditions'
            ? OPERATION_UNIT_STATUS_PRECONDITION_FAILED
            : OPERATION_UNIT_STATUS_FAILED
        : OPERATION_UNIT_STATUS_SUCCEEDED;

    my $ops_db = $self->dbreg->load('cennelops');
    $ops_db->execute(
        'UPDATE `operation_unit`
             SET status = ?,
                 data = CONCAT(data, :data),
                 end_timestamp = ?
             WHERE operation_unit_id = ?',
        {
            status => $status,
            data => Dongry::Type->serialize('text', join '', @{$self->{log}}, (sprintf "[%s] operation unit finished\n", scalar gmtime)),
            end_timestamp => time,
            operation_unit_id => $self->operation_unit_id,
        },
    );

    my $cv = AE::cv;
    $cv->send;
    return $cv;
}

1;
