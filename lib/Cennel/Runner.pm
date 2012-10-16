package Cennel::Runner;
use strict;
use warnings;
use Path::Class;
use Dongry::Database;
use AnyEvent;
use AnyEvent::HTTPD;
use Cennel::MySQL;
use Cennel::Git::Repository;
use Cennel::Action::StartOperation;
use Cennel::Action::ProcessOperationUnit;
use Cennel::Action::RunOperationUnit;
use Wanage::HTTP;
use Cennel::Warabe::App;

sub new_from_config_and_dsns {
    return bless {config => $_[1], dsns => $_[2]}, $_[0];
}

sub new_from_env {
    my $class = shift;
    require Karasuma::Config::JSON;
    my $config = Karasuma::Config::JSON->new_from_env;
    require JSON::Functions::XS;
    my $json_f = file($ENV{MYSQL_DSNS_JSON} || die "|MYSQL_DSNS_JSON| is not set");
    my $json = JSON::Functions::XS::file2perl($json_f);
    return $class->new_from_config_and_dsns($config, $json->{dsns});
}

sub config {
    return $_[0]->{config};
}

sub dsns {
    return $_[0]->{dsns};
}

sub dbreg {
    return $_[0]->{dbreg} if $_[0]->{dbreg};

    my $dbreg = Dongry::Database->create_registry;
    Cennel::MySQL->define_schema($dbreg);
    $dbreg->{Registry}->{cennel}->{sources} = {
        master => {
            dsn => $_[0]->dsns->{cennel},
            writable => 1,
        },
        default => {
            dsn => $_[0]->dsns->{cennel},
        },
    };
    $dbreg->{Registry}->{cennelops}->{sources} = {
        master => {
            dsn => $_[0]->dsns->{cennelops},
            writable => 1,
        },
        default => {
            dsn => $_[0]->dsns->{cennelops},
        },
    };

    return $_[0]->{dbreg} = $dbreg;
}

sub cached_repo_set_d {
    return $_[0]->{cached_repo_set_d} ||= do {
        my $d = dir($_[0]->{config}->get_text('cennel.cached_repo_set_dir_name'));
        $d->mkpath;
        $d->resolve;
    };
}

sub job_action {
    my $self = shift;
    return $self->{job_action} ||= Cennel::Action::ProcessOperationUnit->new_from_dbreg($self->dbreg);
}

sub process_next_as_cv {
    my $self = shift;
    
    my $job = $self->job_action->get_job or return do {
        my $cv = AE::cv;
        $cv->send;
        $cv;
    };

    my $action = Cennel::Action::RunOperationUnit->new_from_dbreg_and_cached_repo_set_d_and_job_values(
        $self->dbreg,
        $self->cached_repo_set_d,
        $job,
    );
    $action->onmessage(sub { $self->log($_[0]) });
    my $cv = AE::cv;
    $action->run_as_cv->cb(sub {
        my $result = $_[0]->recv;
        my $job_action = $self->job_action;
        if ($result->{retry}) {
            $job_action->retry_job($job);
        } else {
            $job_action->complete_job($job);
        }
        if ($result->{failed}) {
            $job_action->skip_remaining_jobs($job->{operation_id});
        }
        if ($job_action->no_more_job_for($job->{operation_id})) {
            require Cennel::Action::EndOperation;
            my $end_action = Cennel::Action::EndOperation->new_from_dbreg_and_operation($self->dbreg, $action->operation);
            undef $action;
            $end_action->run_as_cv->cb(sub {
                $cv->send;
            });
        } else {
            $cv->send;
        }
    });
    return $cv;
}

sub interval {
    return 2;
}

sub web_port {
    return $_[0]->{web_port} ||= $_[0]->{config}->get_text('cennel.web.port');
}

sub web_api_key {
    return $_[0]->{web_api_key} ||= $_[0]->{config}->get_file_base64_text('cennel.web.api_key');
}

sub log {
    my $self = shift;
    warn sprintf "[%s] %d: %s\n", scalar gmtime, $$, $_[0];
}

sub process_as_cv {
    my $self = shift;
    
    my $cv = AE::cv;

    my $schedule_test;
    my $schedule_sleep;
    my $sleeping = 1;

    my $httpd = AnyEvent::HTTPD->new(port => $self->web_port);
    $httpd->reg_cb(request => sub {
        my ($httpd, $req) = @_;
        my $http = Wanage::HTTP->new_from_anyeventhttpd_httpd_and_req($httpd, $req);
        $self->log($http->client_ip_addr->as_text . ': ' . $http->request_method . ' ' . $http->url->stringify);
        my $app = Cennel::Warabe::App->new_from_http($http);
        $http->send_response(onready => sub {
            $app->execute (sub {
                $self->process_http($app);
            });
        });
        $httpd->stop_request;
    });

    $schedule_test = sub {
        $sleeping = 0;
        $self->log("Finding a job...");
        $self->process_next_as_cv->cb($schedule_sleep);
    };
    $schedule_sleep = sub {
        $sleeping = 1;
        $self->log("Sleep @{[$self->interval]}s");
        my $watcher; $watcher = AE::timer $self->interval, 0, sub {
            undef $watcher;
            $schedule_test->();
        };
    };
    
    my $schedule_end = sub {
        my $timer; $timer = AE::timer 0, 0, sub {
            #warn "end...\n";
            $cv->send;
            undef $timer;
        };
        $schedule_test = $schedule_sleep = sub { };
    };
    for my $sig (qw(TERM INT)) {
        my $signal; $signal = AE::signal $sig => sub {
            $self->log("Signal: SIG$sig");
            if ($sleeping) {
                $schedule_end->();
                undef $signal;
                undef $httpd;
            } else {
                $schedule_test = $schedule_sleep = $schedule_end;
                $sleeping = 1; # for second kill
            }
        };
    }

    $schedule_test->();

    return $cv;
}

sub process_http {
    my ($self, $app) = @_;
    my $path = $app->path_segments;

    if ($path->[0] eq 'jobs' and not defined $path->[1]) {
        # /jobs
        $app->requires_request_method({POST => 1});
        $app->requires_basic_auth({api_key => $self->web_api_key});

        my $json = $app->request_json;

        my $branch = ref $json eq 'HASH' ? $json->{ref} || '' : '';
        $branch =~ s{^refs/heads/}{};
        $app->throw_error(400, reason_phrase => 'bad ref') unless $branch;

        my $url = ref $json->{repository} eq 'HASH' ? $json->{repository}->{url} : undef
            or $app->throw_error(400, reason_phrase => 'bad repository.url');
        my $rev = $json->{after}
            or $app->throw_error(400, reason_phrase => 'bad after');
        my $role = ref $json->{hook_args} eq 'HASH' && $json->{hook_args}->{role}
            or $app->throw_error(400, reason_phrase => 'bad role');
        $role =~ s/^\@//;
        my $task = $json->{hook_args}->{task}
            or $app->throw_error(400, reason_phrase => 'bad task');

        my $action = Cennel::Action::StartOperation->new_from_dbreg_and_cached_repo_set_d(
            $self->dbreg, $self->cached_repo_set_d,
        );
        $action->onmessage(sub { $self->log($_[0]) });
        $action->run_as_cv(
            reository_name => $json->{hook_args}->{repository_name} || $url,
            repository_url => $url,
            repository_branch => $branch,
            repository_sha => $rev,
            role_name => $role,
            task_name => $task,
        );
        $app->send_json({operation_id => $action->operation->operation_id});
        return $app->throw;

    } elsif ($path->[0] eq 'operation' and
             defined $path->[1] and $path->[1] =~ /.\.json\z/) {
        # /operation/{operation_id}.json
        $app->requires_basic_auth({api_key => $self->web_api_key});
        my $op_id = $path->[1];
        $op_id =~ s/\.json$//;
        require Cennel::Loader::Operation;
        my $op_loader = Cennel::Loader::Operation->new_from_dbreg_and_operation_id($self->dbreg, $op_id);
        $op_loader->load_operation;
        $op_loader->load_repository;
        $op_loader->load_role;
        my $op = $op_loader->operation;
        require Cennel::Loader::OperationStatus;
        my $loader = Cennel::Loader::OperationStatus->new_from_dbreg_and_operation($self->dbreg, $op);
        $app->send_json($loader->as_jsonable);
        return $app->throw;

    }
    
    return $app->throw_error(404);
}

1;
