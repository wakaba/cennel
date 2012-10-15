package Cennel::Action::ProcessOperationUnit;
use strict;
use warnings;

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

1;
