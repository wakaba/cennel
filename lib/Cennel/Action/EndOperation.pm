package Cennel::Action::EndOperation;
use strict;
use warnings;
use AnyEvent;
use Cennel::Defs::Statuses;
use Web::UserAgent::Functions qw(http_post);

sub new_from_dbreg_and_operation {
    return bless {dbreg => $_[1], operation => $_[2]}, $_[0];
}

sub dbreg {
    return $_[0]->{dbreg};
}

sub operation {
    return $_[0]->{operation};
}

sub config {
    if (@_ > 1) {
        $_[0]->{config} = $_[1];
    }
    return $_[0]->{config};
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

    return $self->add_commit_status_as_cv(
        failed => $status != OPERATION_UNIT_STATUS_SUCCEEDED,
    );
}

sub commit_status_post_url {
    return $_[0]->config->get_text('cennel.repos.commit_status_post_url');
}

sub commit_status_basic_auth {
    my $config = $_[0]->config;
    return [
        $config->get_file_base64_text('cennel.repos.commit_status_basic_auth.user'),
        $config->get_file_base64_text('cennel.repos.commit_status_basic_auth.password'),
    ];
}

sub log_viewer_url {
    return $_[0]->config->get_text('cennel.repos.cennel_log_viewer_url');
}

sub add_commit_status_as_cv {
    my ($self, %args) = @_;
    my $cv = AE::cv;
    my $url = $self->commit_status_post_url;
    my $log_url = $self->log_viewer_url;
    my $op = $self->operation;
    my $state = $args{failed} ? 'failure' : 'success';
    my $title = $args{failed} ? 'Cennel result - failed' : 'Cennel result - success';
    $url =~ s/%s/$op->repository_sha/e;
    $log_url =~ s/%s/$op->operation_id/e;
    http_post
        url => $url,
        basic_auth => $self->commit_status_basic_auth,
        params => {
            repository_url => $op->repository_url,
            branch => $op->repository_branch,
            state => $state,
            target_url => $log_url,
            description => $title,
        },
        anyevent => 1,
        cb => sub {
            my (undef, $res) = @_;
            $cv->send({});
        };
    return $cv;
}

1;
