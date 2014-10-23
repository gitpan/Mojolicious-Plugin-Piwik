#!/usr/bin/env perl
use Test::Mojo;
use Test::More;
use Mojolicious::Lite;
use Mojo::JSON;
use utf8;

$|++;
use lib '../lib';

our $ft = 'auth.pl';

my $t = Test::Mojo->new;

my $app = $t->app;

$app->mode('production');

$app->plugin(Piwik => {
  url => 'sojolicio.us/piwik'
});

my $c = Mojolicious::Controller->new;

$c->app($app);

$c->req->url(Mojo::URL->new('http:/khm.li/Rapunzel'));

$c->app($app);
for ($c->req->headers) {
  $_->user_agent('Firefox');
  $_->referrer('http://khm.li/');
};

my $track = $c->piwik_api(
  Track => {
    idsite => '4',
    api_test => 1,
    res => [1024, 768]
  });

like($track, qr{idsite=4}, 'Tracking 1');
like($track, qr{ua=Firefox}, 'Tracking 1');
like($track, qr{rec=1}, 'Tracking 1');
like($track, qr{urlref=http://khm\.li/}, 'Tracking 1');
like($track, qr{res=1024x768}, 'Tracking 1');

$c->app($app);
for ($c->req->headers) {
  $_->user_agent('Mojo-Test');
  $_->referrer('http://khm.li/');
};

$track = $c->piwik_api(
  Track => {
    idsite => [qw/4 5 6/],
    api_test => 1,
    res => '1024x768',
    action_url => 'http://khm.li/Rapunzel',
    action_name => 'Märchen/Rapunzel'
  });

like($track, qr{idsite=4}, 'Tracking 2');
like($track, qr{ua=Mojo-Test}, 'Tracking 2');
like($track, qr{rec=1}, 'Tracking 2');
like($track, qr{urlref=http://khm\.li/}, 'Tracking 2');
like($track, qr{url=http://khm\.li/Rapunzel}, 'Tracking 2');
like($track, qr{action_name=M%C3%A4rchen/Rapunzel}, 'Tracking 2');
like($track, qr{res=1024x768}, 'Tracking 2');

# Do not track
$c->req->headers->dnt(1);

$track = $c->piwik_api(
  Track => {
    idsite => [qw/4 5 6/],
    api_test => 1,
    res => '1024x768',
    action_url => 'http://khm.li/Rapunzel',
    action_name => 'Märchen/Rapunzel'
  });

ok(!$track, 'Do not track');

# Life tests:
# Testing the piwik api is hard to do ...
my (%param, $f);
if (
  -f ($f = 't/' . $ft) ||
    -f ($f = $ft) ||
      -f ($f = '../t/' . $ft) ||
	-f ($f = '../../t/' . $ft)
      ) {
  if (open (CFG, '<' . $f)) {
    my $cfg = join('', <CFG>);
    close(CFG);
    %param = %{ eval $cfg };
  };
};

unless ($param{url}) {
  done_testing;
  exit;
};

$track = $c->piwik_api(
  Track => {
    idsite => [qw/4 5 6/],
    res => '1024x768',
    action_url => 'http://khm.li/Test',
    action_name => 'Märchen/Test',
    %param
});

ok(!$track, 'Do not track');

$c->req->headers->dnt(0);

$track = $c->piwik_api(
  Track => {
    res => '1024x768',
    %param
});

ok(!$track->{error}, 'No error');
ok($track->{image}, 'Image');
like($track->{image}, qr{base64}, 'Image');
like($track->{image}, qr{image/gif}, 'Image');

done_testing;
