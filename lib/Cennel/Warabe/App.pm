package Cennel::Warabe::App;
use strict;
use warnings;
use Warabe::App;
use Warabe::App::Role::JSON;
push our @ISA, qw(Warabe::App Warabe::App::Role::JSON);

1;
