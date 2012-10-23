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
        url => qq<http://localhost:$port/operation/list.json>,
        basic_auth => [api_key => $data->web_api_key],
        anyevent => 1,
        cb => sub {
            my (undef, $res) = @_;
            test {
                is $res->code, 200;
                my $json = json_bytes2perl $res->content;
                is_deeply $json, [];
                done $c;
                undef $c;
            } $c;
        };
} wait => Test::Cennel::Server->create_as_cv,
    name => 'empty', n => 2;

test {
    my $c = shift;
    my $data = $c->received_data;
    
    my $cv1 = AE::cv;
    my $port = $data->web_port;
    my $op_id;
    http_post_data
        url => qq<http://localhost:$port/jobs>,
        basic_auth => [api_key => $data->web_api_key],
        content => perl2json_bytes +{
            repository => {url => q<hoge:fuga>},
            ref => 'refs/heads/master',
            after => q<aatewgfagageeet23t23ttqtr3q3t33333333aa3>,
            hook_args => {
                role => 'devel1',
                task => 'restart',
            },
        },
        anyevent => 1,
        cb => sub {
            my (undef, $res) = @_;
            test {
                is $res->code, 200;
                my $json = json_bytes2perl $res->content;
                ok $op_id = $json->{operation_id};
                $cv1->send;
            } $c;
        };

    $cv1->cb(sub {
        test {
            http_post_data
                url => qq<http://localhost:$port/operation/list.json>,
                basic_auth => [api_key => $data->web_api_key],
                anyevent => 1,
                cb => sub {
                    my (undef, $res) = @_;
                    test {
                        is $res->code, 200;
                        my $json = json_bytes2perl $res->content;
                        ok $json->[0]->{repository}->{id};
                        delete $json->[0]->{repository}->{id};
                        ok $json->[0]->{role}->{id};
                        delete $json->[0]->{role}->{id};
                        is_deeply $json, [{
                            repository => {
                                url => q<hoge:fuga>,
                                sha => 'aatewgfagageeet23t23ttqtr3q3t33333333aa3',
                                branch => 'master',
                            },
                            role => {name => 'devel1'},
                            task => {name => 'restart'},
                            operation => {
                                status => 2,
                                start_timestamp => time,
                                end_timestamp => 0,
                                data => '',
                            },
                        }];
                        done $c;
                        undef $c;
                    } $c;
                };
        } $c;
    });
} wait => Test::Cennel::Server->create_as_cv,
    name => 'has an operation', n => 6;

run_tests;
