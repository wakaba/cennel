package Test::Cennel::Server;
use strict;
use warnings;
use Test::AnyEvent::MySQL::CreateDatabase;
use JSON::Functions::XS qw(perl2json_bytes);
use MIME::Base64;
use AnyEvent::Util;
use File::Temp qw(tempdir);
use Path::Class;

my $root_d = file(__FILE__)->dir->parent->parent->parent->parent;
my $runner_f = $root_d->file('bin', 'runner.pl');
my $prep_f = $root_d->file('db', 'preparation.txt');

sub create_as_cv {
    my $cv_return = AE::cv;
    my $data = bless {}, 'Test::Cennel::Server::Data';

    my $temp_d = dir(tempdir('TEST-XX'.'XX'.'XX', TMPDIR => 1, CLEANUP => 1));
    my $config_json_f = $temp_d->file('config.json');
    print { $config_json_f->openw } perl2json_bytes +{
        'cennel.web.port' => $data->web_port,
        'cennel.web.api_key' => 'api_key.txt',
        'cennel.cached_repo_set_dir_name' => $temp_d->subdir('repos')->stringify,
    };
    $temp_d->subdir('keys')->mkpath;
    print { $temp_d->file('keys', 'api_key.txt')->openw } encode_base64 $data->web_api_key;
    my $cv = Test::AnyEvent::MySQL::CreateDatabase->new->prep_f_to_cv($prep_f);
    $cv->cb(sub {
        my $mysql_data = $_[0]->recv;
        my $dsns_json_f = $mysql_data->json_f;

        {
            local $ENV{KARASUMA_CONFIG_JSON} = $config_json_f;
            local $ENV{KARASUMA_CONFIG_FILE_DIR_NAME} = $temp_d->subdir('keys');
            local $ENV{MYSQL_DSNS_JSON} = $dsns_json_f;
            run_cmd(
                [$root_d->file('perl'), $runner_f],
                '$$' => \($data->{pid}),
            )->cb(sub {
                undef $mysql_data;
            });
        }
        
        my $timer; $timer = AE::timer 0.5, 0, sub {
            $cv_return->send($data);
            undef $timer;
        };
    });

    return $cv_return;
}

package Test::Cennel::Server::Data;

sub web_port {
    return $_[0]->{web_port} ||= 1024 + int rand 10000;
}

sub web_api_key {
    return $_[0]->{web_api_key} ||= rand 1000000;
}

sub pid {
    return $_[0]->{pid};
}

sub stop_server {
    kill 'TERM', $_[0]->pid;
}

sub DESTROY {
    $_[0]->stop_server;
}

1;
