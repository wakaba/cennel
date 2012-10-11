package Cennel::Action::EndOperation;
use strict;
use warnings;
use AnyEvent;
use Cennel::Defs::Statuses;

sub new_from_dbreg_and_operation {
    return bless {dbreg => $_[1], operation => $_[2]}, $_[0];
}

sub dbreg {
    return $_[0]->{dbreg};
}

sub operation {
    return $_[0]->{operation};
}

sub run_as_cv {
    my $self = shift;
    my $cv = AE::cv;

    my $ops_db = $self->dbreg->load('cennelops');
    my $status = OPERATION_UNIT_STATUS_SUCCEEDED;
    if ($ops_db->select(
        'operation_unit',
        {
            operation_id => $self->operation->operation_id,
            status => {-not => OPERATION_UNIT_STATUS_SUCCEEDED},
        },
        field => 'operation_unit_id',
        limit => 1,
    )->first) {
        $status = OPERATION_UNIT_STATUS_FAILED;
    }

    $self->operation->operation_row->update({
        status => $status,
        end_timestamp => time,
    });

    $cv->send;
    return $cv;
}

1;
