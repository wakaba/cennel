use strict;
use warnings;
use Cwd qw(abs_path);

my ($repo_dir_name, $script_file_name, $role_name, $host_name, $task_name, $json_file_name) = @ARGV;

my $root_dir_name = __FILE__;
$root_dir_name =~ s{[^/\\]+$}{};
$root_dir_name ||= '.';
$root_dir_name .= '/..';
my $cinnamon = abs_path "$root_dir_name/cin";

chdir $repo_dir_name;

my $package = do $script_file_name or die $@;

$package->run(
    role_name => $role_name,
    host_name => length $host_name ? $host_name : undef,
    task_name => $task_name,
    json_file_name => $json_file_name,
    cinnamon => $cinnamon,
);
