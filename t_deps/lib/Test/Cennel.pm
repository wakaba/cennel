package Test::Cennel;
use strict;
use warnings;
use Path::Class;
use lib glob file(__FILE__)->dir->parent->parent->parent->subdir('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::More;
use JSON::Functions::XS qw(perl2json_bytes);
use Web::UserAgent::Functions qw(http_post_data);
use Test::Cennel::Server;
use Exporter::Lite;
use File::Temp qw(tempdir);
use Path::Class;
use AnyEvent;

our @EXPORT = qw(perl2json_bytes http_post_data);
push @EXPORT, @Test::More::EXPORT, @Test::X1::EXPORT;

my $temp_dir = tempdir 'TEST-XX'.'XX'.'XX', TMPDIR => 1, CLEANUP => 1;
my $temp_d = dir($temp_dir);

push @EXPORT, qw(create_git_repository);
sub create_git_repository (;%) {
    my %args = @_;

    my $repo_d = $temp_d->subdir('git-' . rand 100000);
    $repo_d->mkpath;
    system "cd \Q$repo_d\E && git init";
    
    return $repo_d;
}

push @EXPORT, qw(create_git_files);
sub create_git_files ($@) {
    my $d = shift;
    for (@_) {
        my $f = $d->file($_->{name});
        $f->dir->mkpath;
        print { $f->openw } $_->{data};
        system "cd \Q$d\E && git add \Q$_->{name}\E";
    }
}

push @EXPORT, qw(git_commit);
sub git_commit ($;%) {
    my ($d, %args) = @_;
    my $msg = $args{message} || rand;
    system "cd \Q$d\E && git commit -m \Q$msg\E";
}

push @EXPORT, qw(get_git_revision);
sub get_git_revision ($) {
    my $d = shift;
    my $rev = `cd \Q$d\E && git rev-parse HEAD`;
    chomp $rev;
    return $rev;
}

1;
