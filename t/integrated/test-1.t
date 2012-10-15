use strict;
use warnings;
use Path::Class;
use lib glob file(__FILE__)->dir->parent->parent->subdir('t_deps', 'lib')->stringify;
use Test::Cennel;

test {
    my $c = shift;
    my $data = $c->received_data;
    
    my $port = $data->web_port;
    http_post_data
        url => qq<http://localhost:$port/jobs>,
        basic_auth => [api_key => $data->web_api_key],
        content => perl2json_bytes +{
            repository => {url => q<hageafreeee>},
            ref => 'refs/heads/master',
            after => '51224512122',
            hook_args => {
                role => 'myrole1',
                task => 'mytask2',
            },
        },
        anyevent => 1,
        cb => sub {
            my (undef, $res) = @_;
            test {
                is $res->code, 200;
                done $c;
                undef $c;
            } $c;
        };
} wait => Test::Cennel::Server->create_as_cv,
    name => 'insert', n => 1;

run_tests;
