use strict;
use warnings;
use Path::Class;
use lib glob file(__FILE__)->dir->parent->parent->subdir('t_deps', 'lib')->stringify;
use Test::Cennel;

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

run_tests;
