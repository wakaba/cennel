use strict;
use warnings;
use Path::Class;
use lib glob file(__FILE__)->dir->parent->parent->subdir('t_deps', 'lib')->stringify;
use Test::Cennel;
use Test::Cennel::GWServer;

Test::Cennel::GWServer->start_server_as_cv->recv;
$Test::Cennel::Server::GWServerHost = Test::Cennel::GWServer->server_host;

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
    my $repo_d = create_git_repository;
    http_post_data
        url => qq<http://localhost:$port/jobs>,
        basic_auth => [api_key => $data->web_api_key],
        content => perl2json_bytes +{
            repository => {url => $repo_d->stringify},
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
                        ok $json->[0]->{operation}->{start_timestamp};
                        delete $json->[0]->{operation}->{start_timestamp};
                        ok $json->[0]->{operation}->{end_timestamp};
                        delete $json->[0]->{operation}->{end_timestamp};
                        is_deeply $json, [{
                            repository => {
                                url => $repo_d->stringify,
                                sha => 'aatewgfagageeet23t23ttqtr3q3t33333333aa3',
                                branch => 'master',
                            },
                            role => {name => 'devel1'},
                            task => {name => 'restart'},
                            operation => {
                                id => $op_id,
                                status => 3,
                                #data => '',
                            },
                        }];
                        done $c;
                        undef $c;
                    } $c;
                };
        } $c;
    });
} wait => Test::Cennel::Server->create_as_cv,
    name => 'has an operation', n => 8;

run_tests;
Test::Cennel::GWServer->stop_server_as_cv->recv;
