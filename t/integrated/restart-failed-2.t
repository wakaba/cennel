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
    
    my $repo_d = create_git_repository;
    my $temp_d = $repo_d->parent->subdir(rand);
    $temp_d->mkpath;
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
                        hosts => ['host1.localdomain',
                                  'host2.localdomain'],
                    };
                    die;
                }
                'My::Package';
            },
        },
        +{
            name => 'config/cennel/restart.pl',
            data => sprintf q{
                package My::Package;
                sub run {
                    my ($class, %args) = @_;
                    my $temp_dir_name = '%s';
                    my $file_name = "$temp_dir_name/$args{host_name}";
                    open my $file, '>', $file_name or die "$0: $file_name: $!";
                }
                'My::Package';
            }, $temp_d,
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

    my $cv2 = AE::cv;
    $cv1->cb(sub {
        my $timer; $timer = AE::timer 4, 0, sub {
            test {
                http_get
                    url => qq<http://localhost:$port/operation/$op_id.json>,
                    basic_auth => [api_key => $data->web_api_key],
                    anyevent => 1,
                    cb => sub {
                        my (undef, $res) = @_;
                        test {
                            my $json = json_bytes2perl $res->content;
                            is $json->{repository}->{url}, $repo_d->stringify;
                            is scalar keys %{$json->{units}}, 0;
                            is $json->{operation}->{status}, 3, 'global status';
                            ok !-f $temp_d->file('host1.localdomain');
                            ok !-f $temp_d->file('host2.localdomain');
                            $cv2->send;
                        } $c;
                    };
            } $c;
            undef $timer;
        };
    });

    $cv2->cb(sub {
        test {
            http_get
                url => qq<http://$Test::Cennel::Server::GWServerHost/repos/statuses/> . $rev . q<.json>,
                params => {
                    repository_url => $repo_d,
                },
                anyevent => 1,
                cb => sub {
                    my (undef, $res) = @_;
                    test {
                        my $json = json_bytes2perl $res->content;
                        is_deeply $json, [{
                            sha => $rev,
                            target_url => q<http://GW/cennel/logs/> . $op_id,
                            description => 'Cennel result - @devel1 restart - failed',
                            state => 'failure',
                        }];
                        done $c;
                        undef $c;
                    } $c;
                };
        } $c;
    });
} wait => Test::Cennel::Server->create_as_cv,
    name => 'get-hosts failed', n => 8;

run_tests;

Test::Cennel::GWServer->stop_server_as_cv->recv;
