use strict;
use warnings;
use Path::Class;
use lib file(__FILE__)->dir->parent->subdir('lib')->stringify;
use Cennel::AnyEvent::Command::Pipeline;

my $cin = './cin';
my $role = shift;

my $pipe = Cennel::AnyEvent::Command::Pipeline->new(
    cinnamon_command => $cin,
    cinnamon_role => $role,
);

$pipe->push_cennel_need_password;
$pipe->push_cennel_need_password('apache');
$pipe->push_cinnamon('update');
$pipe->push_cinnamon('setup');
$pipe->push_cinnamon('restart');
$pipe->push_cinnamon('check');
$pipe->push_cennel_done;

exit !$pipe->cennel_cv->recv;
