#!/usr/bin/perl
use strict;
use warnings;
use Cennel::Runner;
use AnyEvent;

select STDERR;
$| = 1;
select STDOUT;
$| = 1;

my $runner = Cennel::Runner->new_from_env;
if ($runner->fork_httpd_process) {
    my $cv = AE::cv;
    $cv->begin;
    $cv->begin;
    $runner->process_as_cv->cb(sub { $cv->end });
    $cv->begin;
    $runner->wait_child_processes_as_cv->cb(sub { $cv->end });
    $cv->end;
    $cv->recv;
} else {
    AE::cv->recv;
}
