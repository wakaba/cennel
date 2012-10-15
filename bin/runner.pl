#!/usr/bin/perl
use strict;
use warnings;
use Cennel::Runner;

select STDERR;
$| = 1;
select STDOUT;
$| = 1;

my $runner = Cennel::Runner->new_from_env;
$runner->process_as_cv->recv;
