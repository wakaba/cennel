package Cennel::Task::GetHosts;
use strict;
use warnings;
use JSON::Functions::XS qw(perl2json_bytes);
use Path::Class;
use File::Temp;
use Cennel::AnyEvent::Command::Pipeline;

sub run {
    my (undef, %args) = @_;
    
    my $pipe = Cennel::AnyEvent::Command::Pipeline->new(
        cinnamon_command => $args{cinnamon},
        cinnamon_role => $args{role_name},
        cinnamon_hosts => [$args{host_name}],
    );

    my $temp = File::Temp->new;
    my $file_name = $temp->filename;;

    $pipe->push_command(['make', 'deploy-min-deps']);
    $pipe->push_cinnamon('cinnamon:role:hosts', args => [$file_name]);
    $pipe->push_cennel_done;
    return 0 unless $pipe->cennel_cv->recv;

    my $hosts = [split /,/, scalar file($file_name)->slurp];

    print { file($args{json_file_name})->openw } perl2json_bytes {hosts => $hosts};

    return 1;
}

__PACKAGE__;
