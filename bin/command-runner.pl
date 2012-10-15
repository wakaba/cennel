use strict;
use warnings;
use Path::Class;
use lib glob file(__FILE__)->dir->parent->subdir('modules', '*', 'lib')->absolute;

my ($repo_dir_name, $script_file_name, $role_name, $host_name, $task_name, $json_file_name) = @ARGV;

my $cinnamon = file(__FILE__)->dir->parent->file('cin')->absolute;

chdir $repo_dir_name;

my $package = do $script_file_name or die $@;

$package->run(
    role_name => $role_name,
    host_name => length $host_name ? $host_name : undef,
    task_name => $task_name,
    json_file_name => $json_file_name,
    cinnamon => $cinnamon,
);
