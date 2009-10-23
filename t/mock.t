#!perl -T

use 5.008;
use strict;
use warnings 'all';

use HTTP::Response;
use HTTP::Status 5.817 qw(:constants);
use Test::More 0.82;
use Test::MockObject;

plan tests => 61;

# Create a mock LWP::UserAgent
my $fake_ua = Test::MockObject->new;
$fake_ua->set_isa('LWP::UserAgent');

use Nagios::Plugin::OverHTTP;

my %test = (
	'simple_ok' => {
		description => 'Simple OK test',
		body        => 'OK - I am simple',
		status      => $Nagios::Plugin::OverHTTP::STATUS_OK,
	},
	'simple_warning' => {
		description => 'Simple WARNING test',
		body        => 'WARNING - I am simple',
		status      => $Nagios::Plugin::OverHTTP::STATUS_WARNING,
	},
	'simple_critical' => {
		description => 'Simple CRITICAL test',
		body        => 'CRITICAL - I am simple',
		status      => $Nagios::Plugin::OverHTTP::STATUS_CRITICAL,
	},
	'simple_unknown' => {
		description => 'Simple UNKNOWN test',
		body        => 'UNKNOWN - I am simple',
		status      => $Nagios::Plugin::OverHTTP::STATUS_UNKNOWN,
	},
	'500_status' => {
		description => '500 status',
		body_like   => qr{\A CRITICAL\b}msx,
		http_body   => 'Error.',
		http_status => HTTP_INTERNAL_SERVER_ERROR,
		status      => $Nagios::Plugin::OverHTTP::STATUS_CRITICAL,
	},
	'no_status' => {
		description => 'No status',
		body_like   => qr//,
		status      => $Nagios::Plugin::OverHTTP::STATUS_UNKNOWN,
	},
	'header_status' => {
		description  => 'Header status',
		body         => qr/OK - I am really a warning/,
		status       => $Nagios::Plugin::OverHTTP::STATUS_WARNING,
		http_body    => 'OK - I am really a warning',
		http_headers => { 'X-Nagios-Status' => 'WARNING' },
	},
	'header_status_numeric' => {
		description  => 'Header status numeric',
		body         => qr/OK - I am really a warning/,
		status       => $Nagios::Plugin::OverHTTP::STATUS_WARNING,
		http_body    => 'OK - I am really a warning',
		http_headers => { 'X-Nagios-Status' => 1 },
	},
	'no_status_html_recover' => {
		description => 'No status and strange HTML',
		body_like   => qr/I am title$/m,
		status      => $Nagios::Plugin::OverHTTP::STATUS_UNKNOWN,
		http_body   => "<html>\n<title>I am title</title>\n</html>",
	},
);

$fake_ua->mock('get', sub {
	my ($self, $url) = @_;

	# Change URL to everything after last /
	($url) = $url =~ m{/ (\w+) \z}msx;

	if (exists $test{$url}) {
		my $http_status = $test{$url}->{http_status} || HTTP_OK;
		my $http_body   = $test{$url}->{http_body  } || $test{$url}->{body};

		# Construct a response
		my $response = HTTP::Response->new(
			$http_status,
			HTTP::Status::status_message($http_status),
			undef,
			$http_body,
		);

		if (exists $test{$url}->{http_headers}) {
			foreach my $header (%{ $test{$url}->{http_headers} }) {
				# Set the header in the response
				$response->header($header => $test{$url}->{http_headers}->{$header});
			}
		}

		return $response;
	}
	else {
		return HTTP::Response->new(404, 'Not Found');
	}
});
$fake_ua->mock('timeout', sub {
	my ($self, $timeout) = @_;

	my $old_timeout = $self->{timeout} || 180;

	if (defined $timeout) {
		$self->{timeout} = $timeout;
	}

	return $old_timeout;
});

my $plugin = new_ok('Nagios::Plugin::OverHTTP' => [
	url => 'http://example.net/nagios/check_nonexistant',
	useragent => $fake_ua,
]);

is($plugin->url, 'http://example.net/nagios/check_nonexistant', 'URL is what was set');
isnt($plugin->has_message, 1, 'Has no message yet');
isnt($plugin->has_status, 1, 'Has no status yet');
is($plugin->status, 3, 'Nonexistant plugin has UNKNOWN status');
like($plugin->message, qr/\A UNKNOWN .+ Not \s Found/msx, 'Nonexistant plugin message');

###########################################################################
# CHECK
foreach my $test_url (sort keys %test) {
	# Check the URL
	check_url(
		$plugin,
		"http://example.net/$test_url",
		$test{$test_url}->{status},
		$test{$test_url}->{body  } || $test{$test_url}->{body_like},
		$test{$test_url}->{description},
	);
}

###########################################################################
# CHECK THE DEFAULT STATUS
{
	# Check that it is the default
	check_url($plugin, 'http://example.net/nagios/no_status', $plugin->default_status, qr//ms, 'No status is default');

	# Change the default
	$plugin->default_status('critical');

	# Check that it is the new default
	check_url($plugin, 'http://example.net/nagios/no_status', $Nagios::Plugin::OverHTTP::STATUS_CRITICAL, qr//ms, 'No status successfully critical');
}

exit 0;

sub check_url {
	my ($plugin, $url, $status, $message, $name) = @_;

	# Change the URL
	$plugin->url($url);

	# Make sure it was changed
	is   $plugin->url        , $url   , "$name: URL was set";
	isnt $plugin->has_message, 1      , "$name: Has no message yet";
	isnt $plugin->has_status , 1      , "$name: Has no status yet";
	is   $plugin->status     , $status, "$name: Status is correct";

	if (ref $message eq 'Regexp') {
		like $plugin->message, $message, "$name: Message is correct";
	}
	else {
		is $plugin->message, $message, "$name: Message is correct";
	}

	return $plugin->status, $plugin->message;
}
