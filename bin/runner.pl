#!/usr/bin/perl
use strict;
use warnings;
use Cennel::Runner;

select STDERR;
$| = 1;
select STDOUT;
$| = 1;

my $runner = Cennel::Runner->new_from_env;
if ($runner->fork_httpd_process) {
    $runner->process_as_cv->recv;
} else {
    require AnyEvent;
    AE::cv->recv;
}
