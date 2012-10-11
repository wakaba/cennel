#!/usr/bin/perl
use strict;
use warnings;
use Cennel::Runner;

my $runner = Cennel::Runner->new_from_env;
$runner->process_as_cv->recv;
