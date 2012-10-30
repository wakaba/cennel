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
    warn "Succeeded\n";
    exit 0;
} else {
    warn "Command failed: $@\n" if $@;
    if ($package->can('retry')) {
        warn "Retry...\n";
        if (eval { $package->retry(%args) }) {
            warn "Retry succeeded\n";
            exit 0;
        } else {
            warn "Command failed: $@\n" if $@;
            warn "Retry failed\n";
            exit 1;
        }
    }
    if ($package->can('revert')) {
        if (eval {$package->revert(%args) }) {
            warn "Reverted\n";
            exit 2;
        } else {
            warn "Command failed: $@\n" if $@;
            warn "Revert failed\n";
            exit 1;
        }
    } else {
        warn "Can't revert changes\n";
        exit 1;
    }
}
