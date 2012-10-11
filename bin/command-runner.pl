use strict;
use warnings;

my ($repo_dir_name, $script_file_name, $role_name, $host_name, $task_name, $json_file_name) = @ARGV;

chdir $repo_dir_name;

my $package = do $script_file_name or die $@;

$package->run($role_name, $host_name, $task_name, $json_file_name);
