package Test::Cennel::GWServer;
use strict;
use warnings;
use Test::AnyEvent::plackup;

my $http_server = Test::AnyEvent::plackup->new;
$http_server->server('Twiggy');
$http_server->set_app_code(q{
    use strict;
    use warnings;
    use Wanage::HTTP;
    use JSON::Functions::XS qw(perl2json_bytes);
    my $repos = {};
    my $i = 0;
    return sub {
        my $http = Wanage::HTTP->new_from_psgi_env($_[0]);
        my $path = $http->url->{path};
        if ($path eq '/repos/logs') {
            if ($http->request_method eq 'POST') {
                my $params = $http->request_body_params;
                $i++;
                my $log = {
                    sha => $params->{sha}->[0],
                    title => $params->{title}->[0],
                    data => $params->{data}->[0],
                    id => $i,
                };
                push @{$repos->{$params->{repository_url}->[0]}->{logs} ||= []}, $log;
                $http->set_status(201);
                $http->set_response_header(Location => q</repos/logs/> . $i);
                $http->send_response_body_as_text(perl2json_bytes $log);
                $http->close_response_body;
                return $http->send_response;
            } else {
                my $params = $http->query_params;
                my $logs = $repos->{$params->{repository_url}->[0]}->{logs} ||= [];
                $http->send_response_body_as_text(perl2json_bytes $logs);
                $http->close_response_body;
                return $http->send_response;
            }
        } elsif ($path =~ m{^/repos/statuses/(\S+)\.json$}) {
            if ($http->request_method eq 'POST') {
                my $params = $http->request_body_params;
                my $status = {
                    sha => $1,
                    description => $params->{description}->[0],
                    state => $params->{state}->[0],
                    target_url => $params->{target_url}->[0],
                };
                push @{$repos->{$params->{repository_url}->[0]}->{commit_statuses} ||= []}, $status;
                $http->send_response_body_as_text(perl2json_bytes $status);
                $http->close_response_body;
                return $http->send_response;
            } else {
                my $params = $http->query_params;
                my $statuses = $repos->{$params->{repository_url}->[0]}->{commit_statuses} ||= [];
                $http->send_response_body_as_text(perl2json_bytes $statuses);
                $http->close_response_body;
                return $http->send_response;
            }
        }
        return [404, [], ['404']];
    };
});

my ($server_start_cv, $server_stop_cv);
my $server_host;

sub start_server_as_cv {
    ($server_start_cv, $server_stop_cv) = $http_server->start_server;
    $server_host = 'localhost:' . $http_server->port;
    return $server_start_cv;
}

sub server_host {
    return $server_host;
}

sub stop_server_as_cv {
    $http_server->stop_server;
    undef $http_server;
    return $server_stop_cv;
}

1;
