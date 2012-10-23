use strict;
use warnings;
use Path::Class;
use lib glob file(__FILE__)->dir->parent->subdir('modules', '*', 'lib')->absolute;

my ($repo_dir_name, $script_file_name, $role_name, $host_name, $task_name, $json_file_name) = @ARGV;

my $cinnamon = file(__FILE__)->dir->parent->file('cin')->absolute;

chdir $repo_dir_name;

my $package = do $script_file_name or die $@;

my %args = (
    role_name => $role_name,
    host_name => length $host_name ? $host_name : undef,
    task_name => $task_name,
    json_file_name => $json_file_name,
    cinnamon => $cinnamon,
);

if (eval { $package->run(%args) }) {
    #
} else {
    warn "Command failed: $@\n";
    if ($package->can('revert')) {
        if (eval {$package->revert(%args) }) {
            warn "Reverted\n";
        } else {
            warn "Revert failed\n";
        }
    } else {
        warn "Can't revert changes\n";
    }
    exit 1;
}
