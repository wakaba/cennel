package Test::Cennel;
use strict;
use warnings;
use Path::Class;
use lib glob file(__FILE__)->dir->parent->parent->parent->subdir('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::More;
use JSON::Functions::XS qw(perl2json_bytes);
use Web::UserAgent::Functions qw(http_post_data);
use Test::Cennel::Server;
use Exporter::Lite;

our @EXPORT = qw(perl2json_bytes http_post_data);
push @EXPORT, @Test::More::EXPORT, @Test::X1::EXPORT;

1;
