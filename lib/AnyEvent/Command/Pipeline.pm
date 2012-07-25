package AnyEvent::Command::Pipeline;
use strict;
use warnings;
use AnyEvent;
use AnyEvent::Util;
use Scalar::Util qw(weaken);

sub new {
    my $class = shift;
    return bless {
        @_,
        actions => [],
        next_action_id => 1,
    }, $class;
}

sub on_info {
    if (@_ > 1) {
        $_[0]->{on_info} = $_[1];
    }
    return $_[0]->{on_info} || sub {
        my ($self, %args) = @_;
        print '[' . gmtime() . '] ' . $args{action}->{action_id} . ': ' . $args{message}, "\n";
    };
}

sub on_stdout {
    if (@_ > 1) {
        $_[0]->{on_stdout} = $_[1];
    }
    return $_[0]->{on_stdout} || sub {
        my ($self, %args) = @_;
        if (defined $args{message}) {
            print STDOUT join '',
                map { $args{action}->{action_id} . ': ' . $_ . "\n" }
                split /\x0D?\x0A/, $args{message}, -1;
        } else {
            print STDOUT $args{action}->{action_id} . ": End of stdout\n";
        }
    };
}

sub on_stderr {
    if (@_ > 1) {
        $_[0]->{on_stderr} = $_[1];
    }
    return $_[0]->{on_stderr} || sub {
        my ($self, %args) = @_;
        if (defined $args{message}) {
            print STDERR join '',
                map { $args{action}->{action_id} . ': ' . $_ . "\n" }
                split /\x0D?\x0A/, $args{message};
        } else {
            print STDERR $args{action}->{action_id} . ": End of stderr\n";
        }
    };
}

sub on_error {
    if (@_ > 1) {
        $_[0]->{on_error} = $_[1];
    }
    return $_[0]->{on_error} || sub {
        my ($self, %args) = @_;
        print '[' . gmtime() . '] ' . 
            ($args{action} ? $args{action}->{action_id} . ': ' : '') .
            $args{message}, "\n";
    };
}

sub on_empty {
    if (@_ > 1) {
        $_[0]->{on_empty} = $_[1];
    }
    return $_[0]->{on_empty} || sub { };
}

sub push_command {
    my ($self, $command, %args) = @_;
    push @{$self->{actions}}, {type => 'command', command => $command, %args};
    $self->_schedule_next_action;
}

sub push_cb {
    my ($self, $code) = @_;
    push @{$self->{actions}}, {type => 'code', code => $code};
    $self->_schedule_next_action;
}

sub _schedule_next_action {
    my $self = shift;
    return unless @{$self->{actions}};

    unless ($self->{current_cv}) {
        $self->{current_cv} = AE::cv;
        $self->{current_cv}->cb(sub {
            delete $self->{current_cv};
            $self->_run_next_action;
        });
        my $timer; $timer = AE::timer 0, 0, sub {
            undef $timer;
            $self->{current_cv}->send;
        };
    }
}

sub _run_next_action {
    weaken(my $self = shift);
    my $action = shift @{$self->{actions}} or do {
        $self->on_empty->($self);
        return;
    };

    if ($action->{type} eq 'command') {
        $action->{action_id} = $self->{next_action_id}++;
        my $on_done = sub {
            my %args = @_;
            ($action->{on_error} || $self->on_error)
                ->($self, %args, message => "Exit with status $args{status}")
                if $args{is_error};
            #$args{action}->{on_done}->(%args)
            #    if $args{action}->{on_done} and defined $args{status};
        };
        my $cv2 = $self->{current_cv} = AE::cv;
        $self->on_info->(
            $self,
            action => $action,
            message => '$ ' . (
                ref $action->{command} eq 'ARRAY'
                    ? (join ' ', map { quotemeta } @{$action->{command}})
                    : 'sh -c ' . quotemeta $action->{command}
            ),
        );

        my $cv = run_cmd
            $action->{command},
            '>' => sub {
                if (defined $_[0]) {
                    $self->on_stdout->($self, action => $action, message => $_[0]);
                } else {
                    $self->on_info->($self, action => $action, message => 'End of stdout');
                }
            },
            '2>' => sub {
                if (defined $_[0]) {
                    $self->on_stderr->($self, action => $action, message => $_[0]);
                } else {
                    $self->on_info->($self, action => $action, message => 'End of stderr');
                }
            },
            %{$action->{descriptors} or {}},
            '$$' => \($self->{child_pids}->{$action->{action_id}}),
        ;
        $cv->cb(sub {
            my $result = $_[0]->recv;
            my $return = $result >> 8;
            $on_done->(
                is_error => $return != 0,
                status => $return,
                action => $action,
            );
            $cv2->send;
        });
    } elsif ($action->{type} eq 'code') {
        $self->{current_cv} = $action->{code}->() || do {
            my $cv = AE::cv;
            my $timer; $timer = AE::timer 0, 0, sub {
                undef $timer;
                $cv->send;
            };
            $cv;
        };
        die "Callback did not return cv"
            unless UNIVERSAL::isa($self->{current_cv}, 'AnyEvent::CondVar');
    } else {
        die "Action type |$action->{type}| is not supported";
    }

    $self->{current_cv}->cb(sub {
        delete $self->{current_cv};
        $self->_run_next_action;
    });

    unless ($self->{signal}) {
        delete $self->{signal_received};
        for (qw(INT TERM QUIT)) { # and HUP...
            $self->{signal}->{$_} = AE::signal $_ => sub {
                $self->on_error->($self, message => 'Signal received');
                if ($self->{signal_received}) {
                    $self->cancel_actions;
                    for (values %{$self->{child_pids} or {}}) {
                        next unless defined $_;
                        kill 9, $_;
                    }
                } else {
                    $self->{signal_received} = 1;
                    for (values %{$self->{child_pids} or {}}) {
                        next unless defined $_;
                        kill 1, $_;
                    }
                }
            };
        }
    }
}

sub cancel_actions {
    my $self = shift;
    $self->{actions} = [];
    $self->on_empty->($self);
}

sub DESTROY {
    if (our $DetectLeak) {
        warn ref($_[0]) . " is leaking!";
    }
}

1;
