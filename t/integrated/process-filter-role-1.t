use strict;
use warnings;
use Path::Class;
use lib glob file(__FILE__)->dir->parent->parent->subdir('t_deps', 'lib')->stringify;
use Test::Cennel;
use Test::Cennel::GWServer;
use AnyEvent::Timer::Retry;

Test::Cennel::GWServer->start_server_as_cv->recv;
$Test::Cennel::Server::GWServerHost = Test::Cennel::GWServer->server_host;

test {
    my $c = shift;
    my $data = $c->received_data;
    
    my $repo_d = create_git_repository;
    my $temp_f = $repo_d->parent->file(rand);
    create_git_files $repo_d, 
        +{
            name => 'config/cennel/get-hosts.pl',
            data => q{
                package My::Package;
                use Path::Class;
                use JSON::Functions::XS qw(perl2json_bytes);
                sub run {
                    my ($class, %args) = @_;
                    my $json_f = file($args{json_file_name});
                    print { $json_f->openw } perl2json_bytes +{
                        hosts => ['host1.localdomain'],
                    };
                }
                'My::Package';
            },
        },
        +{
            name => 'config/cennel/restart.pl',
            data => q{ package My::Package; sub run { } 'My::Package' },
        };
    git_commit $repo_d;
    my $rev = get_git_revision $repo_d;

    my $cv1 = AE::cv;
    my $port = $data->web_port;
    my $op_id;
    http_post_data
        url => qq<http://localhost:$port/jobs>,
        basic_auth => [api_key => $data->web_api_key],
        content => perl2json_bytes +{
            repository => {url => $repo_d->stringify},
            ref => 'refs/heads/master',
            after => $rev,
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
        my $timer; $timer = AE::timer 4, 0, sub {
            http_get
                url => qq<http://localhost:$port/operation/$op_id.json>,
                basic_auth => [api_key => $data->web_api_key],
                anyevent => 1,
                cb => sub {
                    my (undef, $res) = @_;
                    test {
                        my $json = json_bytes2perl $res->content;
                        is $json->{repository}->{url}, $repo_d->stringify;
                        is $json->{operation}->{status}, 2;
                        done $c;
                        undef $c;
                    } $c;
                };
            undef $timer;
        };
    });
} wait => Test::Cennel::Server->create_as_cv(config => {
    'cennel.filter.role_names' => 'hoge,fuga',
}), name => 'role no match', n => 4;

test {
    my $c = shift;
    my $data = $c->received_data;
    
    my $repo_d = create_git_repository;
    my $temp_f = $repo_d->parent->file(rand);
    create_git_files $repo_d, 
        +{
            name => 'config/cennel/get-hosts.pl',
            data => q{
                package My::Package;
                use Path::Class;
                use JSON::Functions::XS qw(perl2json_bytes);
                sub run {
                    my ($class, %args) = @_;
                    my $json_f = file($args{json_file_name});
                    print { $json_f->openw } perl2json_bytes +{
                        hosts => ['host1.localdomain'],
                    };
                }
                'My::Package';
            },
        },
        +{
            name => 'config/cennel/restart.pl',
            data => q{ package My::Package; sub run { } 'My::Package' },
        };
    git_commit $repo_d;
    my $rev = get_git_revision $repo_d;

    my $cv1 = AE::cv;
    my $port = $data->web_port;
    my $op_id;
    http_post_data
        url => qq<http://localhost:$port/jobs>,
        basic_auth => [api_key => $data->web_api_key],
        content => perl2json_bytes +{
            repository => {url => $repo_d->stringify},
            ref => 'refs/heads/master',
            after => $rev,
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
        my $timer; $timer = AnyEvent::Timer::Retry->new(
            on_retry => sub {
                my $done = shift;
                http_get
                    url => qq<http://localhost:$port/operation/$op_id.json>,
                    basic_auth => [api_key => $data->web_api_key],
                    anyevent => 1,
                    cb => sub {
                        my (undef, $res) = @_;
                        my $json = json_bytes2perl $res->content;
                        $done->($json->{operation}->{status} == 3, $json);
                    };
            },
            on_end => sub {
                my ($result, $json) = @_;
                test {
                    is $json->{repository}->{url}, $repo_d->stringify;
                    is $json->{operation}->{status}, 3;
                    done $c;
                    undef $c;
                    undef $timer;
                } $c;
            },
        );
    });
} wait => Test::Cennel::Server->create_as_cv(config => {
    'cennel.filter.role_names' => 'hoge,master,devel1',
}), name => 'role match', n => 4;

run_tests;
Test::Cennel::GWServer->stop_server_as_cv->recv;
