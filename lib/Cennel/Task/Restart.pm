package Cennel::Task::Restart;
use strict;
use warnings;
use Cennel::AnyEvent::Command::Pipeline;
use Path::Class;
use MIME::Base64;
use File::Temp;

my $temp_dir = File::Temp->newdir('DEPLOY-XX'.'XX'.'XX', TMPDIR => 1);
my $temp_d = dir($temp_dir);

sub run {
    my ($class, %args) = @_;

    my $rev = `git rev-parse HEAD`;
    chomp $rev;

    return $class->_run(%args, revision => $rev, save_old_revision => 1);
}

sub retry {
    my $class = shift;
    return $class->run(@_);
}

sub revert {
    my ($class, %args) = @_;

    my $old_f = $temp_d->file('old-rev.txt');
    my $old_rev = -f $old_f ? scalar $old_f->slurp : undef;
    unless ($old_rev) {
        warn "Can't revert - old revision is not known\n";
        return 0;
    }

    my $rev = `git rev-parse HEAD`;
    chomp $rev;
    if ($old_rev eq $rev) {
        warn "Can't revert - old revision is same as new revision\n";
        return 0;
    }

    return $class->_run(%args, revision => $old_rev);
}

sub _run {
    my ($class, %args) = @_;

    my $pipe = Cennel::AnyEvent::Command::Pipeline->new(
        cinnamon_command => $args{cinnamon},
        cinnamon_role => $args{role_name},
        cinnamon_hosts => [$args{host_name}],
    );
    $class->_run_with_pipe($pipe, %args);
    $pipe->push_cennel_done;

    return unless $pipe->cennel_cv->recv;
}

sub _run_with_pipe {
    die __PACKAGE__ . "->_run_with_pipe not implemented";
}

__PACKAGE__;
