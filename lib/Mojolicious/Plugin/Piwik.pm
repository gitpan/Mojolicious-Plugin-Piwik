package Mojolicious::Plugin::Piwik;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream 'b';
use Mojo::UserAgent;


our $VERSION = '0.06';


# Todo:
# - Add tracking API support
#   See http://piwik.org/docs/javascript-tracking/
# - Add eCommerce support
#   http://piwik.org/docs/ecommerce-analytics/
# - Add ImageGraph API support.
# - Improve error handling.


# Register plugin
sub register {
  my ($plugin, $mojo, $plugin_param) = @_;

  $plugin_param ||= {};

  # Load parameter from Config file
  if (my $config_param = $mojo->config('Piwik')) {
    $plugin_param = { %$config_param, %$plugin_param };
  };

  my $embed = $plugin_param->{embed} //
    ($mojo->mode eq 'production' ? 1 : 0);

  # Add 'piwik_tag' helper
  $mojo->helper(
    piwik_tag => sub {

      # Do not embed
      return '' unless $embed;

      # Controller is not needed
      shift;

      my $site_id = shift || $plugin_param->{site_id} || 1;
      my $url     = shift || $plugin_param->{url};

      # No piwik url
      return b('<!-- No Piwik-URL given -->') unless $url;

      # Clear url
      for ($url) {
	s{^https?:/*}{}i;
	s{piwik\.(?:php|js)$}{}i;
	s{(?<!/)$}{/};
      };

      # Create piwik tag
      b(<<"SCRIPTTAG")->squish;
<script type="text/javascript">var _paq=_paq||[];(function(){var
u='http'+((document.location.protocol=='https:')?'s':'')+'://$url';
with(_paq){push(['setSiteId',$site_id]);push(['setTrackerUrl',u+'piwik.php']);
push(['trackPageView'])};var
d=document,g=d.createElement('script'),s=d.getElementsByTagName('script')[0];
if(!s){s=d.getElementsByTagName('head')[0].firstChild};
with(g){type='text/javascript';defer=async=true;
src=u+'piwik.js';s.parentNode.insertBefore(g,s)}})();</script>
<noscript><img src="http://${url}piwik.php?idSite=${site_id}&amp;rec=1" alt=""
style="border:0" /></noscript>
SCRIPTTAG
    });


  # Add 'piwik_api' helper
  $mojo->helper(
    piwik_api => sub {
      my ($c, $method, $param, $cb) = @_;

      # Get api_test parameter
      my $api_test = delete $param->{api_test};

      # Get piwik url
      my $url = delete $param->{url} || $plugin_param->{url};

      $url =~ s{https?://}{}i;
      $url = ($param->{secure} ? 'https' : 'http') . '://' . $url;


      # Token Auth
      my $token_auth = delete $param->{token_auth} ||
	               $plugin_param->{token_auth} || 'anonymous';

      # Site id
      my $site_id = $param->{site_id} ||
	            $param->{idSite}  ||
                    $plugin_param->{site_id} || 1;

      # delete unused parameters
      delete @{$param}{qw/site_id idSite format module method/};

      # Create request method
      $url = Mojo::URL->new($url);
      $url->query(
	module => 'API',
	method => $method,
	format => 'JSON',
	idSite => ref $site_id ? join(',', @$site_id) : $site_id,
	token_auth => $token_auth
      );

      # Urls as array
      if ($param->{urls}) {
	if (ref $param->{urls}) {
	  my $i = 0;
	  foreach (@{$param->{urls}}) {
	    $url->query({'urls[' . $i++ . ']' => $_});
	  };
	}
	else {
	  $url->query({urls => $param->{urls}});
	};
	delete $param->{urls};
      };

      # Range with periods
      if ($param->{period}) {

	# Delete period
	my $period = lc delete $param->{period};

	# Delete date
	my $date = delete $param->{date};

	# Get range
	if ($period eq 'range') {
	  $date = ref $date ? join(',', @$date) : $date;
	};

	if ($period =~ /^(?:day|week|month|year|range)$/) {
	  $url->query({
	    period => $period,
	    date => $date
	  });
	};
      };

      # Todo: Handle Filter

      # Merge query
      $url->query($param);

      # Return string for api testing
      return $url->to_string if $api_test;

      # Create Mojo::UserAgent
      my $ua = Mojo::UserAgent->new(max_redirects => 2);

      # Todo: Handle json errors!

      # Blocking
      unless ($cb) {
	my $tx = $ua->get($url);
	return $tx->res->json if $tx->success;
	return;
      }

      # Non-Blocking
      else {
	$ua->get(
	  $url => sub {
	    my ($ua, $tx) = @_;
	    my $json = $tx->res->json if $tx->success;
	    $cb->($json);
	  });
	Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
      };
    });
};


1;


__END__

=pod

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Piwik - Use Piwik in Mojolicious


=head1 SYNOPSIS

  # On startup
  plugin 'Piwik' => {
    url => 'piwik.khm.li',
    site_id => 1
  };

  # In Template
  %= piwik_tag

  # In controller
  my $json = $c->piwik_api('API.getPiwikVersion');


=head1 DESCRIPTION

L<Mojolicious::Plugin::Piwik> is a simple plugin for embedding
L<Piwik|http://piwik.org/> Analysis in your Mojolicious app.


=head1 METHODS

=head2 C<register>

  # Mojolicious
  $app->plugin(Piwik => {
    url => 'piwik.khm.li',
    site_id => 1
  });

  # Mojolicious::Lite
  plugin 'Piwik' => {
    url => 'piwik.khm.li',
    site_id => 1
  };

  # Or in your config file
  {
    Piwik => {
      url => 'piwik.khm.li',
      site_id => 1
    }
  }


Called when registering the plugin.
Accepts the following parameters:

=over 2

=item C<url>

URL of your Piwik instance.

=item C<site_id>

The id of the site to monitor. Defaults to 1.

=item C<embed>

Activates or deactivates the embedding of the script tag.
Defaults to C<true> if Mojolicious is in production mode,
defaults to C<false> otherwise.

=item C<token_auth>

Token for authentication. Used only for the Piwik API.

=back

All parameters can be set either on registration or
as part of the configuration file with the key C<Piwik>.


=head1 HELPERS

=head2 C<piwik_tag>

  %= piwik_tag
  %= piwik_tag 1
  %= piwik_tag 1, 'piwik.khm.li'

Renders a script tag that asynchronously loads the Piwik
javascript file from your Piwik instance.
Accepts optionally a site id and the url of your Piwik
instance. Defaults to the site id and the url given when the plugin
was registered.

This tag should be included at the bottom
of the body tag of your website.


=head2 C<piwik_api>

  # In Controller - blocking ...
  my $json = $c->piwik_api(
    'Actions.getPageUrl' => {
      token_auth => 'MyToken',
      idSite => [4,7],
      period => 'day',
      date   => 'today'
    }
  );

  # ... or async
  $c->piwik_api(
    'Actions.getPageUrl' => {
      token_auth => 'MyToken',
      idSite => [4,7],
      period => 'day',
      date   => 'today'
    } => sub {
      my $json = shift;
      # ...
    }
  );

Sends a Piwik API request and returns the response as a hash
or array reference (the decoded JSON response).
Accepts the API method, a hash reference
with request parameters as described in the
L<Piwik API|http://piwik.org/docs/analytics-api/>, and
optionally a callback, if the request is meant to be non-blocking.

In addition to the parameters of the API reference, the following
parameters are allowed:

=over 2

=item C<url>

The url of your Piwik instance.
Defaults to the url given when the plugin was registered.

=item C<secure>

Boolean value that indicates a request using the https scheme.
Defaults to false.

=item C<api_test>

Boolean value that indicates a test request, that returns the
created request url instead of the JSON response.
Defaults to false.

=back

C<idSite> is an alias of C<site_id> and defaults to the id
of the plugin registration.
Some parameters are allowed to be array references instead of string values,
for example C<idSite> and C<date> (for ranges).

  my $json = $c->piwik_api(
    'API.get' => {
      site_id => [4,5],
      period  => 'range',
      date    => ['2012-11-01', '2012-12-01'],
      secure  => 1
    });


=head1 LIMITATIONS

Currently the API requests always expect JSON, so it's not recommended
for the C<ImageGraph> API.
The plugin is also limited to the Analysis API and lacks support for
eCommerce tracking.


=head1 TESTING

To test the plugin against your Piwik instance, create a configuration
file with the necessary information as a perl data structure in C<t/auth.pl>
and run C<make test>, for example:

  {
    token_auth => '123456abcdefghijklmnopqrstuvwxyz',
    url => 'http://piwik.khm.li/',
    site_id => 1
  };


=head1 DEPENDENCIES

L<Mojolicious>.


=head1 AVAILABILITY

  https://github.com/Akron/Mojolicious-Plugin-Piwik


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012, Nils Diewald.

This program is free software, you can redistribute it
and/or modify it under the same terms as Perl.

This plugin was developed for
L<khm.li - Kinder- und Hausmärchen der Brüder Grimm|http://khm.li/>.

=cut
