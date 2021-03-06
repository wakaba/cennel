package Cennel::Action::StartOperation;
use strict;
use warnings;
use AnyEvent;
use Dongry::Type;
use Cennel::Defs::Statuses;
use Cennel::Object::Operation;
use Cennel::Git::Repository;

sub new_from_dbreg_and_cached_repo_set_d {
    return bless {dbreg => $_[1], cached_repo_set_d => $_[2]}, $_[0];
}

sub dbreg {
    return $_[0]->{dbreg};
}

sub cached_repo_set_d {
    return $_[0]->{cached_repo_set_d};
}

sub operation {
    return $_[0]->{operation};
}

sub role_name {
    return $_[0]->{role_name};
}

sub task_name {
    return $_[0]->{task_name};
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
    $self->create_operation_record_as_cv(@_)->cb(sub {
        $self->get_target_host_list_as_cv($_[0]->recv)->cb(sub {
            my $data = $_[0]->recv;
            if ($data) {
                $self->get_target_host_ids_as_cv($data)->cb(sub {
                    $self->insert_unit_jobs_as_cv($_[0]->recv)->cb(sub {
                        $cv->send($_[0]->recv);
                    });
                });
            } else {
                $cv->send(undef);
            }
        });
    });
    return $cv;
}

sub create_operation_record_as_cv {
    my ($self, %args) = @_;

    my $def_db = $self->dbreg->load('cennel');

    $def_db->insert('repository', [{
        repository_id => $def_db->bare_sql_fragment('UUID_SHORT()'),
        name => defined $args{repository_name} && length $args{repository_name}
            ? $args{repository_name} : $args{repository_url},
        url => $args{repository_url},
        created => time,
    }], duplicate => 'ignore');
    my $repo_row = $def_db->select('repository', {
        url => $args{repository_url},
    }, source_name => 'master')->first_as_row;
    my $repo_id = $repo_row->get('repository_id');

    $def_db->insert('role', [{
        repository_id => $repo_id,
        role_id => $def_db->bare_sql_fragment('UUID_SHORT()'),
        name => $args{role_name},
        created => time,
    }], duplicate => 'ignore');
    my $role_row = $def_db->select('role', {
        repository_id => $repo_id,
        name => $args{role_name},
    }, source_name => 'master')->first_as_row;
    $self->{role_name} = $args{role_name};

    my $ops_db = $self->dbreg->load('cennelops');

    my $op_id = $ops_db->execute('select uuid_short() as uuid')->first->{uuid};
    $ops_db->insert('operation', [{
        operation_id => $op_id,
        repository_id => $repo_id,
        repository_branch => $args{repository_branch},
        repository_sha => $args{repository_sha},
        role_id => $role_row->get('role_id'),
        task_name => $args{task_name},
        status => OPERATION_UNIT_STATUS_STARTED,
        start_timestamp => time,
    }]);
    my $op_row = $ops_db->select('operation', {
        operation_id => $op_id,
    }, source_name => 'master')->first_as_row;
    $self->{task_name} = $args{task_name};
    
    $self->{operation} = Cennel::Object::Operation->new_from_rows(
        operation_row => $op_row,
        repository_row => $repo_row,
        role_row => $role_row,
    );

    my $cv = AE::cv;
    $cv->send;
    return $cv;
}

sub get_target_host_list_as_cv {
    my $self = shift;
    my $repo = Cennel::Git::Repository->new_from_operation_and_cached_repo_set_d($self->operation, $self->cached_repo_set_d);
    my $log = [];
    my $onmessage = $self->onmessage;
    $repo->onmessage(sub {
        push @$log, $_[0];
        $onmessage->($_[0]);
    });
    my $cv = AE::cv;
    $repo->run_repo_command_as_cv('get-hosts', $self->role_name, '', $self->task_name)->cb(sub {
        if (@$log) {
            my $ops_db = $self->dbreg->load('cennelops');
            my $op_id = $self->operation->operation_id;
            $ops_db->execute(
                'UPDATE `operation` SET data = CONCAT(data, :data)
                     WHERE operation_id = ?',
                {
                    data => Dongry::Type->serialize('text', join '', @$log),
                    operation_id => $op_id,
                },
            );
        }
        my ($status, $data) = @{$_[0]->recv};
        $cv->send($status ? undef : $data);
    });
    return $cv;
}

sub get_target_host_ids_as_cv {
    my ($self, $list) = @_;

    my $hosts = ref $list eq 'HASH' && $list->{hosts} && ref $list->{hosts} eq 'ARRAY' ? $list->{hosts} : [];

    my $cv = AE::cv;
    if (@$hosts) {
        my $def_db = $self->dbreg->load('cennel');
        $def_db->insert(
            'host',
            [map {
                +{
                    host_id => $def_db->bare_sql_fragment('UUID_SHORT()'),
                    name => $_,
                    created => time,
                };
            } @$hosts],
            duplicate => 'ignore',
        );
        
        my $host_ids = $def_db->select(
            'host',
            {name => {-in => $hosts}},
            fields => 'host_id',
        )->all->map(sub { $_->{host_id} });
        $cv->send($host_ids);
    } else {
        $cv->send([]);
    }

    return $cv;
}

sub insert_unit_jobs_as_cv {
    my ($self, $host_ids) = @_;

    my $ops_db = $self->dbreg->load('cennelops');
    my $op = $self->operation;
    my $op_id = $op->operation_id;

    my $n = 0;
    if (@$host_ids) {
        $ops_db->insert(
            'operation_unit',
            [map {
                +{
                    operation_unit_id => $ops_db->bare_sql_fragment('UUID_SHORT()'),
                    operation_id => $op_id,
                    host_id => $_,
                    status => OPERATION_UNIT_STATUS_INITIAL,
                    scheduled_timestamp => time,
                },
            } @$host_ids],
        );
        my $unit_ids = $ops_db->select(
            'operation_unit',
            {operation_id => $op_id},
            fields => 'operation_unit_id',
            source_name => 'master',
        )->all->map(sub { $_->{operation_unit_id} });
        if (@$unit_ids) {
            $ops_db->insert(
                'operation_unit_job',
                [map {
                    +{
                        operation_unit_id => $_,
                        operation_id => $op_id,
                        repository_id => $op->repository_id,
                        repository_branch => $op->repository_branch,
                        role_id => $op->role_id,
                        task_name => $op->task_name,
                        scheduled_timestamp => time,
                    };
                } @$unit_ids],
            );
            $n += @$unit_ids;
        }
    }

    my $cv = AE::cv;
    $cv->send($n);
    return $cv;
}

1;
