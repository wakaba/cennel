package Cennel::Action::ProcessOperationUnit;
use strict;
use warnings;
use Cennel::Defs::Statuses;

sub new_from_dbreg {
    return bless {dbreg => $_[1]}, $_[0];
}

sub dbreg {
    return $_[0]->{dbreg};
}

sub timeout {
    return 20*60;
}

sub db {
    my $self = shift;
    return $self->{db} ||= $self->dbreg->load('cennelops');
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
        },
        order => [process_started => 'ASC'],
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
