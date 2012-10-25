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
            data => sprintf q{
                package My::Package;
                sub run {
                    my ($class, %args) = @_;
                    warn "%s...\n";
                    open my $file, '>', '%s' or die "$0: %s: $!";
                    print $file $args{role_name}, "\n";
                    print $file $args{host_name}, "\n";
                    print $file $args{task_name}, "\n";
                }
                'My::Package';
            }, $temp_f, $temp_f, $temp_f,
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
            test {
                is scalar $temp_f->slurp,
                    qq{devel1\nhost1.localdomain\nrestart\n};

                http_get
                    url => qq<http://localhost:$port/operation/$op_id.json>,
                    basic_auth => [api_key => $data->web_api_key],
                    anyevent => 1,
                    cb => sub {
                        my (undef, $res) = @_;
                        test {
                            my $json = json_bytes2perl $res->content;
                            is $json->{repository}->{url}, $repo_d->stringify;
                            is scalar keys %{$json->{units}}, 1;
                            my $id = [keys %{$json->{units}}]->[0];
                            is $json->{units}->{$id}->{status}, 4, 'unit status';
                            ok $json->{units}->{$id}->{data};
                            ok $json->{units}->{$id}->{start_timestamp};
                            ok $json->{units}->{$id}->{end_timestamp};
                            is $json->{operation}->{status}, 4, 'global status';
                            ok $json->{operation}->{data};
                            ok $json->{operation}->{start_timestamp};
                            ok $json->{operation}->{end_timestamp};
                            done $c;
                            undef $c;
                        } $c;
                    };
            } $c;
            undef $timer;
        };
    });
} wait => Test::Cennel::Server->create_as_cv,
    name => 'restart a host', n => 13;

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
                            is scalar keys %{$json->{units}}, 2;
                            is_deeply [sort { $a cmp $b } map { $_->{host}->{name} } values %{$json->{units}}], [qw(host1.localdomain host2.localdomain)];
                            my $id = [keys %{$json->{units}}]->[0];
                            is $json->{units}->{$id}->{status}, 4, 'unit status';
                            is $json->{operation}->{status}, 4, 'global status';
                            ok -f $temp_d->file('host1.localdomain');
                            ok -f $temp_d->file('host2.localdomain');
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
                            description => 'Cennel result - @devel1 restart - succeeded',
                            state => 'success',
                        }];
                        done $c;
                        undef $c;
                    } $c;
                };
        } $c;
    });
} wait => Test::Cennel::Server->create_as_cv,
    name => 'restart two hosts', n => 10;

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
                        hosts => [],
                    };
                }
                'My::Package';
            },
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
        my $timer; $timer = AE::timer 2, 0, sub {
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
                            is $json->{operation}->{status}, 4, 'global status';
                            ok $json->{operation}->{data};
                            ok $json->{operation}->{start_timestamp};
                            ok $json->{operation}->{end_timestamp};
                            done $c;
                            undef $c;
                        } $c;
                    };
            } $c;
            undef $timer;
        };
    });
} wait => Test::Cennel::Server->create_as_cv,
    name => 'restart empty', n => 8;

run_tests;

Test::Cennel::GWServer->stop_server_as_cv->recv;
