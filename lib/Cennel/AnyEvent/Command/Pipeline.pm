package Cennel::AnyEvent::Command::Pipeline;
use strict;
use warnings;
use Scalar::Util qw(weaken);
use Encode;
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Command::Pipeline;
use Term::ReadKey;
use MIME::Base64 qw(encode_base64url decode_base64url);
push our @ISA, qw(AnyEvent::Command::Pipeline);

sub new {
    my $self = shift->SUPER::new(@_);
    my $cv = $self->{cennel_cv} = AE::cv;
    
    my $on_error = $self->on_error;
    $self->on_error(sub {
        my ($self, %args) = @_;
        $on_error->(@_);
        $self->cancel_actions;
        print "Failed!\n";
        ReadMode 0 if $self->{revert_noecho};
        $cv->send(0);
    });

    $self->stdout(\*STDOUT);
    $self->stderr(\*STDOUT);

    return $self;
}

sub push_cennel_done {
    my $self = shift;
    my $cv = $self->{cennel_cv};
    $self->push_cb(sub {
        print "Done!\n";
        $cv->send(1);
    });
}

sub cinnamon_command {
    return $_[0]->{cinnamon_command} || die "cinnamon_command is not set";
}

sub cinnamon_role {
    return $_[0]->{cinnamon_role} || die "cinnamon role is not set";
}

sub cinnamon_hosts {
    if (@_ > 1) {
        $_[0]->{cinnamon_hosts} = $_[1];
    }
    return $_[0]->{cinnamon_hosts};
}

sub cinnamon_descriptors {
    weaken (my $self = shift);
    return $self->{cinnamon_descriptors} ||= do {
        my ($pr3, $pw3) = AnyEvent::Util::portable_pipe;
        my ($pr4, $pw4) = AnyEvent::Util::portable_pipe;

        my $read_handle;
        my $write_handle;
        $write_handle = AnyEvent::Handle->new(
            fh => $pw3,
            on_eof => sub { $_[0]->destroy; $read_handle->destroy; },
            on_error => sub { $_[0]->destroy },
        );
        $read_handle = AnyEvent::Handle->new(
            fh => $pr4,
            on_eof => sub { $_[0]->destroy; $write_handle->destroy },
            on_error => sub { $_[0]->destroy },
        );
        my $on_line_read; $on_line_read = sub {
            if ($_[1] =~ /^password (\S*)$/) {
                my $euser = $1;
                my $user = decode 'utf-8', decode_base64url $euser;
                $self->cennel_with_password($user, sub {
                    my $pass = encode_base64url $_[0];
                    $write_handle->push_write("password $euser $pass\n");
                });
            }
            $read_handle->push_read(line => $on_line_read);
        };
        $read_handle->push_read(line => $on_line_read);
        
        +{
            '3<' => $pr3,
            '4>' => $pw4,
        };
    };
}

sub cennel_with_password {
    my ($self, $user, $code) = @_;
    if (defined $self->{password}->{defined $user ? $user : ''}) {
        return $code->($self->{password}->{defined $user ? $user : ''});
    }

    local $| = 1;
    if (defined $user and length $user) {
        print "Password ($user): ";
    } else {
        print "Your password: ";
    }
    $self->{revert_noecho}++;
    ReadMode "noecho";
    my $w; $w = AnyEvent->io(fh => \*STDIN, poll => 'r', cb => sub {
        chomp (my $pass = <STDIN>);
        ReadMode 0;
        $self->{revert_noecho}--;
        print "\n";
        $code->($self->{password}->{defined $user ? $user : ''} = $pass);
        undef $w;
    });
}

sub push_cennel_need_password {
    weaken(my $self = shift);
    my $user = shift;
    $self->push_cb(sub {
        my $cv = AE::cv;
        $self->cennel_with_password($user, sub { $cv->send });
        return $cv;
    });
}

sub push_cennel_set_password {
    weaken(my $self = shift);
    my ($user, $password) = @_;
    $self->push_cb(sub {
        my $cv = AE::cv;
        $self->{password}->{defined $user ? $user : ''}
            = ref $password eq 'CODE' ? $password->() : $password;
        $cv->send;
        return $cv;
    });
}

sub cennel_cv {
    return $_[0]->{cennel_cv};
}

sub push_cinnamon {
    my ($self, $task, %args) = @_;
    my $hosts = $self->cinnamon_hosts;
    $self->push_command(
        [
            $self->cinnamon_command,
            $self->cinnamon_role,
            $task,
            ($hosts ? '--hosts=' . join ',', @$hosts : ()),
            '--key-chain-fds=3,4',
        ],
        descriptors => $self->cinnamon_descriptors,
        envs => {
            PATH => $ENV{PMBP_ORIG_PATH} || $ENV{PATH},
        },
    );
}

1;
