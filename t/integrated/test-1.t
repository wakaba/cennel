use strict;
use warnings;
use Path::Class;
use lib glob file(__FILE__)->dir->parent->parent->subdir('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::More;
use AnyEvent::Util;
use File::Temp qw(tempdir);
use MIME::Base64;
use JSON::Functions::XS qw(perl2json_bytes);
use Test::AnyEvent::MySQL::CreateDatabase;
use Web::UserAgent::Functions qw(http_post_data);

test {
    my $c = shift;

    my $root_d = file(__FILE__)->dir->parent->parent;
    my $runner_f = $root_d->file('bin', 'runner.pl');
    my $prep_f = $root_d->file('db', 'preparation.txt');

    my $temp_d = dir(tempdir('TEST-XX'.'XX'.'XX', TMPDIR => 1, CLEANUP => 1));
    my $config_json_f = $temp_d->file('config.json');
    my $port = 1024 + int rand 10000; # XXX
    my $api_key = rand 1000000;
    print { $config_json_f->openw } perl2json_bytes +{
        'cennel.web.port' => $port,
        'cennel.web.api_key' => 'api_key.txt',
        'cennel.cached_repo_set_dir_name' => $temp_d->subdir('repos')->stringify,
    };
    $temp_d->subdir('keys')->mkpath;
    print { $temp_d->file('keys', 'api_key.txt')->openw } encode_base64 $api_key;
    my $cv = Test::AnyEvent::MySQL::CreateDatabase->new->prep_f_to_cv($prep_f);
    $cv->cb(sub {
        my $data = $_[0]->recv;
        test {
            my $dsns_json_f = $data->json_f;

            my $pid;
    {
        local $ENV{KARASUMA_CONFIG_JSON} = $config_json_f;
        local $ENV{KARASUMA_CONFIG_FILE_DIR_NAME} = $temp_d->subdir('keys');
        local $ENV{MYSQL_DSNS_JSON} = $dsns_json_f;
        run_cmd(
            [$root_d->file('perl'), $runner_f],
            '$$' => \$pid,
        )->cb(sub {
            done $c;
            undef $c;
            undef $data;
        });
    }
            
            my $timer; $timer = AE::timer 0.5, 0, sub {
                http_post_data
                    url => qq<http://localhost:$port/jobs>,
                    basic_auth => [api_key => $api_key],
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
                            kill 'TERM', $pid;
                        } $c;
                    };
                undef $timer;
            };

        } $c;
    });
};

run_tests;
