package Cennel::Git::Repository;
use strict;
use warnings;
use AnyEvent::Git::Repository;
push our @ISA, qw(AnyEvent::Git::Repository);
use AnyEvent::Util;
use JSON::Functions::XS qw(file2perl);
use Path::Class;

sub new_from_operation_and_cached_repo_set_d {
    my ($class, $op, $cached_d) = @_;
    my $self = $class->new_from_url_and_cached_repo_set_d($op->repository_url, $cached_d);
    $self->{operation} = $op;
    $self->branch($op->repository_branch);
    $self->revision($op->repository_sha);
    return $self;
}

sub operation {
    return $_[0]->{operation};
}

sub root_d {
    return $_[0]->{root_d} ||= file(__FILE__)->dir->parent->parent->parent->resolve;
}

sub perl {
    return $_[0]->{perl} ||= $_[0]->root_d->file('perl')->stringify;
}

sub command_runner {
    return $_[0]->{command_runner} ||= $_[0]->root_d->file('bin', 'command-runner.pl')->stringify;
}

sub run_repo_command_as_cv {
    my ($self, $command, $role_name, $host_name, $task_name) = @_;
    my $cv = AE::cv;
    $self->clone_as_cv->cb(sub {
        my $script_f = $self->temp_repo_d->file('config', 'cennel', $command . '.pl');
        if (-f $script_f) {
            my $json_f = $self->temp_repo_d->file('local', 'tmp', 'cennel-' . (rand 1000000) . '.json');
            $json_f->dir->mkpath;
            run_cmd(
                [
                    $self->perl,
                    $self->command_runner,
                    $self->temp_repo_d,
                    $script_f->absolute,
                    $role_name,
                    $host_name,
                    $task_name,
                    $json_f,
                ],
                '<' => '/dev/null',
                '>' => sub { $self->print_message($_[0]) if defined $_[0] },
                '2>' => sub { $self->print_message($_[0]) if defined $_[0] },
            )->cb(sub {
                my $return = $_[0]->recv;
                $self->print_message("$script_f ends with status $return\n");
                my $json;
                if (not $return and -f $json_f) {
                    $json = file2perl $json_f;
                }
                $cv->send([$return, $json]);
            });
        } else {
            $self->print_message("$script_f not found\n");
            $cv->send([1, undef]);
        }
    });
    return $cv;
}

1;
