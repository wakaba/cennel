package Cennel::Action::ProcessOperationUnit;
use strict;
use warnings;
use Cennel::Defs::Statuses;

sub new_from_dbreg_and_config {
    return bless {dbreg => $_[1], config => $_[2]}, $_[0];
}

sub dbreg {
    return $_[0]->{dbreg};
}

sub config {
    return $_[0]->{config};
}

sub timeout {
    return 20*60;
}

sub db {
    my $self = shift;
    return $self->{db} ||= $self->dbreg->load('cennelops');
}

sub filters_as_where {
    my $self = shift;
    return $self->{filters_as_where} ||= do {
        my $config = $self->config;
        my $where = {};
        my $incomplete;
        if ($config) {
            my $defs_db = $self->dbreg->load('cennel');
            
            my $repos = $config->get_text('cennel.filter.repository_urls');
            $repos = defined $repos ? [split /,/, $repos] : [];
            if (@$repos) {
                $where->{repository_id} = {-in => $defs_db->select('repository', {url => {-in => $repos}}, fields => 'repository_id')->all->map(sub { $_->{repository_id} })};
                unless (@{$where->{repository_id}->{-in}}) {
                    $where->{repository_id}->{-in} = [0];
                    $incomplete = 1;
                }
                $incomplete = 1 if @$repos != @{$where->{repository_id}->{-in}};
            }

            my $branches = $config->get_text('cennel.filter.repository_branches');
            $branches = defined $branches ? [split /,/, $branches] : [];
            if (@$branches) {
                $where->{repository_branch}->{-in} = $branches;
            }

            my $roles = $config->get_text('cennel.filter.role_names');
            $roles = defined $roles ? [split /,/, $roles] : [];
            if (@$roles) {
                $where->{role_id} = {-in => $defs_db->select('role', {name => {-in => $roles}}, fields => 'role_id')->all->map(sub { $_->{role_id} })};
                unless (@{$where->{role_id}->{-in}}) {
                    $where->{role_id}->{-in} = [0];
                    $incomplete = 1;
                }
                $incomplete = 1 if @$repos != @{$where->{role_id}->{-in}};
            }
        }
        return $where if $incomplete;
        $where;
    };
}

sub get_job {
    my $self = shift;
    my $db = $self->dbreg->load('cennelops');
    return undef unless $db->has_table('operation_unit_job');
    my $pid = $db->execute(
        'select uuid_short() as uuid', {},
        source_name => 'master',
    )->first->{uuid};
    $db->update(
        'operation_unit_job',
        {
            process_id => $pid,
            process_started => time,
        },
        where => {
            process_started => {'<=', time - $self->timeout},
            %{$self->filters_as_where},
        },
        order => [process_started => 'ASC', scheduled_timestamp => 'ASC'],
        limit => 1,
    );
    return $db->select(
        'operation_unit_job',
        {process_id => $pid},
        source_name => 'master',
    )->first; # or undef
}

sub retry_job {
    my ($self, $job) = @_;
    $self->db->update(
        'operation_unit_job',
        {process_started => 1},
        where => {operation_unit_id => $job->{operation_unit_id}},
    );
}

sub complete_job {
    my ($self, $job) = @_;
    $self->db->delete(
        'operation_unit_job',
        {operation_unit_id => $job->{operation_unit_id}},
    );
}

sub no_more_job_for {
    my ($self, $op_id) = @_;
    return not $self->db->select(
        'operation_unit_job',
        {operation_id => $op_id},
        fields => 'operation_id',
    )->first;
}

sub skip_remaining_jobs {
    my ($self, $op_id) = @_;
    my $pid = $self->db->execute(
        'select uuid_short() as uuid', {},
        source_name => 'master',
    )->first->{uuid};
    $self->db->update(
        'operation_unit_job',
        {process_started => time, process_id => $pid},
        where => {
            operation_id => $op_id,
            process_started => {'<=', time - $self->timeout},
        },
    );
    my $unit_ids = $self->db->select(
        'operation_unit_job',
        {process_id => $pid},
        fields => 'operation_unit_id',
        source_name => 'master',
    )->all->map(sub { $_->{operation_unit_id} });
    $self->db->update(
        'operation_unit',
        {status => OPERATION_UNIT_STATUS_SKIPPED},
        where => {
            operation_unit_id => {-in => $unit_ids},
        },
    ) if @$unit_ids;
    $self->db->delete(
        'operation_unit_job',
        {operation_unit_id => {-in => $unit_ids}},
    ) if @$unit_ids;
}

1;
