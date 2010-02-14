package Nagios::Plugin::OverHTTP;

use 5.008001;
use strict;
use warnings 'all';

###########################################################################
# METADATA
our $AUTHORITY = 'cpan:DOUGDUDE';
our $VERSION   = '0.13_002';

###########################################################################
# MOOSE
use Moose 0.74;
use MooseX::StrictConstructor 0.08;

###########################################################################
# MOOSE TYPES
use Nagios::Plugin::OverHTTP::Library 0.12 qw(
	Hostname
	HTTPVerb
	Path
	Status
	Timeout
	URL
);

###########################################################################
# MODULE IMPORTS
use Carp qw(croak);
use HTTP::Request 5.827;
use HTTP::Status 5.817 qw(:constants);
use LWP::UserAgent;
use Nagios::Plugin::OverHTTP::PerformanceData;
use Readonly 1.03;
use URI;

###########################################################################
# ALL IMPORTS BEFORE THIS WILL BE ERASED
use namespace::clean 0.04 -except => [qw(meta)];

###########################################################################
# MOOSE ROLES
with 'MooseX::Getopt';

###########################################################################
# PUBLIC CONSTANTS
Readonly our $STATUS_OK       => 0;
Readonly our $STATUS_WARNING  => 1;
Readonly our $STATUS_CRITICAL => 2;
Readonly our $STATUS_UNKNOWN  => 3;

###########################################################################
# PRIVATE CONSTANTS
Readonly my $HEADER_MESSAGE     => 'X-Nagios-Information';
Readonly my $HEADER_PERFORMANCE => 'X-Nagios-Performance';
Readonly my $HEADER_STATUS      => 'X-Nagios-Status';

###########################################################################
# ATTRIBUTES
has 'autocorrect_unknown_html' => (
	is            => 'rw',
	isa           => 'Bool',
	documentation => q{When a multiline HTML response without a status is }
	                .q{received, this will add something meaningful to the}
	                .q{ first line},

	default       => 1,
);
has 'critical' => (
	is            => 'rw',
	isa           => 'HashRef[Str]',
	documentation => q{Specifies performance levels that result in a }
	                .q{critical status},

	default       => sub { {} },
);
has 'default_status' => (
	is            => 'rw',
	isa           => Status,
	documentation => q{The default status if none specified in the response},

	coerce        => 1,
	default       => $STATUS_UNKNOWN,
);
has 'hostname' => (
	is            => 'rw',
	isa           => Hostname,
	documentation => q{The hostname on which the URL is located},

	builder       => '_build_hostname',
	clearer       => '_clear_hostname',
	lazy          => 1,
	predicate     => '_has_hostname',
	trigger       => \&_reset_trigger,
);
has 'message' => (
	is            => 'ro',
	isa           => 'Str',

	builder       => '_build_message',
	clearer       => '_clear_message',
	lazy          => 1,
	predicate     => 'has_message',
	traits        => ['NoGetopt'],
);
has 'path' => (
	is            => 'rw',
	isa           => Path,
	documentation => q{The path of the plugin on the host},

	builder       => '_build_path',
	clearer       => '_clear_path',
	coerce        => 1,
	lazy          => 1,
	predicate     => '_has_path',
	trigger       => \&_reset_trigger,
);
has 'performance_data' => (
	is            => 'ro',
	isa           => 'ArrayRef',
	documentation => q{Array of performance data from the plugin},

	clearer       => '_clear_performance_data',
	predicate     => 'has_performance_data',
);
has 'ssl' => (
	is            => 'rw',
	isa           => 'Bool',
	documentation => q{Whether to use SSL (defaults to no)},

	builder       => '_build_ssl',
	clearer       => '_clear_ssl',
	lazy          => 1,
	predicate     => '_has_ssl',
	trigger       => \&_reset_trigger,
);
has 'timeout' => (
	is            => 'rw',
	isa           => Timeout,
	documentation => q{The HTTP request timeout in seconds (defaults to nothing)},

	clearer       => 'clear_timeout',
	predicate     => 'has_timeout',
);
has 'status' => (
	is            => 'ro',
	isa           => Status,

	builder       => '_build_status',
	clearer       => '_clear_status',
	lazy          => 1,
	predicate     => 'has_status',
	traits        => ['NoGetopt'],
);
has 'url' => (
	is            => 'rw',
	isa           => URL,
	documentation => q{The URL to the remote nagios plugin},

	builder       => '_build_url',
	clearer       => '_clear_url',
	lazy          => 1,
	predicate     => '_has_url',
	trigger       => sub {
		my ($self) = @_;

		# Clear the state
		$self->_clear_state;

		# Populate out other properties from the URL
		$self->_populate_from_url;
	},
);
has 'useragent' => (
	is            => 'rw',
	isa           => 'LWP::UserAgent',

	default       => sub { LWP::UserAgent->new; },
	lazy          => 1,
	traits        => ['NoGetopt'],
);
has 'verb' => (
	is            => 'rw',
	isa           => HTTPVerb,
	documentation => q{Specifies the HTTP verb with which to make the request},

	default       => 'GET',
);
has 'warning' => (
	is            => 'rw',
	isa           => 'HashRef[Str]',
	documentation => q{Specifies performance levels that result in a }
	                .q{warning status},

	default       => sub { {} },
);

###########################################################################
# METHODS
sub check {
	my ($self) = @_;

	# Get the response of the plugin
	my $response = $self->_request;

	if (!_response_contains_plugin_output($response)) {
		# Get the response error information
		my ($status, $message) = $self->_response_error_information($response);

		# Set the new state
		$self->_set_state($status, $message);

		# End check early
		return;
	}

	# Default status and message
	my ($status, $message);

	# Default performance data
	my @performance_data = ();

	if (_should_parse_body($response)) {
		# Parse the body
		$self->_parse_response_body($response,
			\$status, \$message, \@performance_data # Parse alters these
		);
	}

	if (defined $response->header($HEADER_MESSAGE)) {
		# The message will be from the header
		$message = join qq{\n},
			$response->header($HEADER_MESSAGE);
	}

	if (defined $response->header($HEADER_STATUS)) {
		# The status will be from the header
		$status = to_Status($response->header($HEADER_STATUS));
	}

	if (defined $response->header($HEADER_PERFORMANCE)) {
		# Add additional performance metrics
		my $header_data = join q{ }, $response->header($HEADER_PERFORMANCE);

		# Push
		push @performance_data,
			map { Nagios::Plugin::OverHTTP::PerformanceData->new($_) }
				Nagios::Plugin::OverHTTP::PerformanceData->split_performance_string($header_data);
	}

	if (!defined $status) {
		# The status was not found in the response
		$status = $self->default_status;

		if ($self->autocorrect_unknown_html
			&& !defined $response->header('X-Nagios-Information')) {
			# The setting is active to automatically correct unknown HTML
			if ($message =~ m{\S+\s*[\r\n]+\s*\S+}msx) {
				# This is a multi-line response.
				if ($message =~ m{<(?:html|body|head)[^>]*>}imsx) {
					# This looks like an HTML response. Most likely it is a
					# response from the server that was intended for a user
					# to see.

					# This will be searching through the content to find
					# something to use as the first line.

					# See if a title or h1 can be found
					my ($title) = $message =~ m{<title[^>]*>(.+?)</title>}imsx;
					my ($h1   ) = $message =~ m{<h1   [^>]*>(.+?)</h1   >}imsx;

					if (defined $title) {
						# There was a title, so add it as the first line of the
						# message
						$message = sprintf "%s\n%s", $title, $message;
					}
					elsif (defined $h1) {
						# There was a h1, so add it as the first line of the
						# message
						$message = sprintf "%s\n%s", $h1, $message;
					}
				}
			}
		}
	}

	#XXX: Fix later
	DATA:
	foreach my $data (@performance_data) {
		my $label = $data->label;

		if ($status != $STATUS_CRITICAL
			&& exists $self->critical->{$label}) {
			# Check for critical since not critical already
			if ($data->is_within_range($self->critical->{$label})) {
				# Set new status to critical
				$status = $STATUS_CRITICAL;

				# Since this is the worst status, stop here
				last DATA;
			}
		}
		if ($status != $STATUS_WARNING
			&& $status != $STATUS_CRITICAL
			&& exists $self->warning->{$label}) {
			# Check for warning since not warning or critical already
			if ($data->is_within_range($self->warning->{$label})) {
				# Set new status to warning
				$status = $STATUS_WARNING;
			}
		}
	}

	# Set the plugin state
	$self->_set_state($status, $message);

	# Set the performance data
	$self->{performance_data} = \@performance_data;

	return;
}
sub run {
	my ($self) = @_;

	# Print the message to stdout
	print $self->message;

	# Return the status code
	return $self->status;
}

###########################################################################
# PRIVATE METHODS
sub _build_after_check {
	my ($self, $attribute) = @_;

	# Preform the check
	$self->check;

	# Return the specified attribute for build
	return $self->{$attribute};
}
sub _build_from_url {
	my ($self, $attribute) = @_;

	# Populate all fields from the URL
	$self->_populate_from_url;

	# Return the specified attribute for build
	return $self->{$attribute};
}
sub _build_hostname {
	return shift->_build_from_url('hostname');
}
sub _build_message {
	return shift->_build_after_check('message');
}
sub _build_path {
	return shift->_build_from_url('path');
}
sub _build_ssl {
	return shift->_build_from_url('ssl');
}
sub _build_status {
	return shift->_build_after_check('status');
}
sub _build_url {
	my ($self) = @_;

	if (!$self->_has_hostname) {
		croak 'Unable to build the URL due to no hostname being provided';
	}
	elsif (!$self->_has_path) {
		croak 'Unable to build the URL due to no path being provided.';
	}

	# Form the URI object
	my $url = URI->new(sprintf 'http://%s%s', $self->{hostname}, $self->{path});

	if ($self->_has_ssl && $self->ssl) {
		# Set the SSL scheme
		$url->scheme('https');
	}

	# Set the URL
	return $url->as_string;
}
sub _clear_state {
	my ($self) = @_;

	$self->_clear_message;
	$self->_clear_status;

	# Nothing useful to return, so chain
	return $self;
}
sub _parse_response_body {
	my ($self, $response, $status_r, $message_r, $performance_data_r) = @_;

	# Set the message to the decoded content body
	${$message_r} = $response->decoded_content;

	# Parse for the status code
	if (${$message_r} =~ m{\A (?:[^a-z]+ \s+)? (OK|WARNING|CRITICAL|UNKNOWN)}msx) {
		# Found the status
		${$status_r} = to_Status($1);
	}

	if (${$message_r} =~ m{\|}msx) {
		# Looks like there is performance data to parse somewhere
		my @message_lines = split m{[\r\n]{1,2}}msx, ${$message_r};

		# Get the data from the first line
		my (undef, $data) = split m{\|}msx, $message_lines[0];

		# Search through the other lines for long performance data
		LINE:
		foreach my $line (1..$#message_lines) {
			if ($message_lines[$line] =~ m{\| ([^\r\n]+)}msx) {
				# This line starts the long performance data
				my $long_data = join q{ }, $1,
					@message_lines[($line+1)..$#message_lines];

				$data = defined $data ? "$data $long_data" : $long_data;

				last LINE;
			}
		}

		if (defined $data) {
			# Parse all the performance data
			my @data = map { Nagios::Plugin::OverHTTP::PerformanceData->new($_) }
				Nagios::Plugin::OverHTTP::PerformanceData->split_performance_string($data);

			# Add to performance data array
			push @{$performance_data_r}, @data;
		}
	}

	return;
}
sub _populate_from_url {
	my ($self) = @_;

	if (!$self->_has_url) {
		croak 'Unable to build requested attributes, as no URL as been defined';
	}

	# Create a URI object from the url
	my $uri = URI->new($self->{url});

	# Set the hostname
	$self->{hostname} = $uri->host;

	# Set the path
	$self->{path} = to_Path($uri->path);

	# Set SSL state
	$self->{ssl} = $uri->scheme eq 'https';

	# Nothing useful to return, so chain
	return $self;
}
sub _request {
	my ($self) = @_;

	# Save the current timeout for the useragent
	my $old_timeout = $self->useragent->timeout;

	# Set the useragent's timeout to our timeout
	# if a timeout has been declared.
	if ($self->has_timeout) {
		$self->useragent->timeout($self->timeout);
	}

	# Form the HTTP request
	my $request = HTTP::Request->new($self->verb, $self->url);

	# Get the response of the plugin
	my $response = $self->useragent->request($request);

	# Restore the previous timeout value to the useragent
	$self->useragent->timeout($old_timeout);

	# Return the response
	return $response;
}
sub _reset_trigger {
	my ($self) = @_;

	# Clear the state
	$self->_clear_state;

	# Clear the generated URL
	$self->_clear_url;

	return;
}
sub _response_error_information {
	my ($self, $response) = @_;

	if ($response->is_success) {
		# This does not contain any error information
		croak 'This response is not in error';
	}

	# Information to return
	my ($status, $message) = ($STATUS_UNKNOWN, $response->status_line);

	if (HTTP::Status::is_server_error($response->code)) {
		# The response is a server error, which is critical
		$status = $STATUS_CRITICAL;
	}

	if ($response->code == HTTP_INTERNAL_SERVER_ERROR) {
		# This response likely came directly from LWP::UserAgent
		if ($response->message eq 'read timeout') {
			# Failure due to timeout
			my $timeout = $self->has_timeout ? $self->timeout
			                                 : $self->useragent->timeout
			                                 ;

			# Make the message explicitly about the timeout
			$message = sprintf 'Socket timeout after %d seconds', $timeout;
		}
		elsif ($response->message =~ m{\(connect: \s timeout\)}msx) {
			# Failure to connect to the host server
			$message = 'Connection refused';
		}
	}

	# Return status and message
	return $status, $message;
}
sub _set_state {
	my ($self, $status, $message) = @_;

	my %status_prefix_map = (
		$STATUS_OK       => 'OK',
		$STATUS_WARNING  => 'WARNING',
		$STATUS_CRITICAL => 'CRITICAL',
		$STATUS_UNKNOWN  => 'UNKNOWN',
	);

	if ($message !~ m{\A $status_prefix_map{$status}}msx) {
		$message = sprintf '%s - %s', $status_prefix_map{$status}, $message;
	}

	$self->{message} = $message;
	$self->{status}  = $status;

	# Nothing useful to return, so chain
	return $self;
}

###########################################################################
# PRIVATE FUNCTIONS
sub _response_contains_plugin_output {
	my ($response) = @_;

	# It MUST contain output if it is a success
	return $response->is_success;
}
sub _should_parse_body {
	my ($response) = @_;

	# Should if header message not present
	return !defined $response->header($HEADER_MESSAGE);
}

###########################################################################
# MAKE MOOSE OBJECT IMMUTABLE
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Nagios::Plugin::OverHTTP - Nagios plugin to check over the HTTP protocol.

=head1 VERSION

Version 0.13_002

=head1 SYNOPSIS

  my $plugin = Nagios::Plugin::OverHTTP->new(
      url => 'https://myserver.net/nagios/check_some_service.cgi',
  );

  my $plugin = Nagios::Plugin::OverHTTP->new(
      hostname => 'myserver.net',
      path     => '/nagios/check_some_service.cgi',
      ssl      => 1,
  );

  my $status  = $plugin->status;
  my $message = $plugin->message;

=head1 DESCRIPTION

This Nagios plugin provides a way to check services remotely over the HTTP
protocol.

=head1 CONSTRUCTOR

This is fully object-oriented, and as such before any method can be used, the
constructor needs to be called to create an object to work with.

=head2 new

This will construct a new plugin object.

=over

=item B<< new(%attributes) >>

C<< %attributes >> is a HASH where the keys are attributes (specified in the
L</ATTRIBUTES> section).

=item B<< new($attributes) >>

C<< $attributes >> is a HASHREF where the keys are attributes (specified in the
L</ATTRIBUTES> section).

=back

=head2 new_with_options

This is identical to L</new>, except with the additional feature of reading the
C<@ARGV> in the invoked scope. C<@ARGV> will be parsed for command-line
arguments. The command-line can contain any variable that L</new> can take.
Arguments should be in the following format on the command line:

  --url=http://example.net/check_something
  --url http://example.net/check_something
  # Note that quotes may be used, based on your shell environment

  # For Booleans, like SSL, you would use:
  --ssl    # Enable SSL
  --no-ssl # Disable SSL

  # For HashRefs, like warning and critical, you would use:
  --warning name=value --warning name2=value2

=head1 ATTRIBUTES

  # Set an attribute
  $object->attribute_name($new_value);

  # Get an attribute
  my $value = $object->attribute_name;

=head2 autocorrect_unknown_html

B<Added in version 0.10>; be sure to require this version for this feature.

This is a Boolean of wether or not to attempt to add a meaningful first line to
the message when the HTTP response did not include the Nagios plugin status
and the message looks like HTML and has multiple lines. The title of the web
page will be added to the first line, or the first H1 element will. The default
for this is on.

=head2 critical

B<Added in version 0.14>; be sure to require this version for this feature.

This is a hash reference specifying different performance names (as the hash
keys) and what threshold they need to be to result in a critical status. The
format for the threshold is specified in L</PERFORMANCE THRESHOLD>.

=head2 default_status

B<Added in version 0.09>; be sure to require this version for this feature.

This is the default status that will be used if the remote plugin does not
return a status. The default is "UNKNOWN." The status may be the status number,
or a string with the name of the status, like:

  $plugin->default_status('CRITICAL');

=head2 hostname

This is the hostname of the remote server. This will automatically be populated
if L</url> is set.

=head2 path

This is the path to the remove Nagios plugin on the remote server. This will
automatically be populated if L</url> is set.

=head2 ssl

This is a Boolean of whether or not to use SSL over HTTP (HTTPS). This defaults
to false and will automatically be updated to true if a HTTPS URL is set to
L</url>.

=head2 timeout

This is a positive integer for the timeout of the HTTP request. If set, this
will override any timeout defined in the useragent for the duration of the
request. The plugin will not permanently alter the timeout in the useragent.
This defaults to not being set, and so the useragent's timeout is used.

=head2 url

This is the URL of the remote Nagios plugin to check. If not supplied, this will
be constructed automatically from the L</hostname> and L</path> attributes.

=head2 useragent

This is the useragent to use when making requests. This defaults to
L<LWP::Useragent> with no options. Currently this must be an L<LWP::Useragent>
object.

=head2 verb

B<Added in version 0.12>; be sure to require this version for this feature.

This is the HTTP verb that will be used to make the HTTP request. The default
value is C<GET>.

=head2 warning

B<Added in version 0.14>; be sure to require this version for this feature.

This is a hash reference specifying different performance names (as the hash
keys) and what threshold they need to be to result in a warning status. The
format for the threshold is specified in L</PERFORMANCE THRESHOLD>.

=head1 METHODS

=head2 check

This will run the remote check. This is usually not needed, as attempting to
access the message or status will result in the check being performed.

=head2 run

This will run the plugin in a standard way. The message will be printed to
standard output and the status code will be returned. Good for doing the
following:

  my $plugin = Plugin::Nagios::OverHTTP->new_with_options;

  exit $plugin->run;

=head1 PERFORMANCE THRESHOLD

Anywhere a performance threshold is accepted, the threshold value can be in any
of the following formats (same as listed in
L<http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT>):

=over 4

=item C<< <number> >>

This will cause an alert if the level is less than zero or greater than
C<< <number> >>.

=item C<< <number>: >>

This will cause an alert if the level is less than C<< <number> >>.

=item C<< ~:<number> >>

This will cause an alert if the level is greater than C<< <number> >>.

=item C<< <number>:<number2> >>

This will cause an alert if the level is less than C<< <number> >> or greater
than C<< <number2> >>.

=item C<< @<number>:<number2> >>

This will cause an alert if the level is greater than or equal to
C<< <number> >> and less than or equal to C<< <number2> >>. This is basically
the exact opposite of the previous format.

=back

=head1 PROTOCOL

=head2 HTTP STATUS

The protocol that this plugin uses to communicate with the Nagios plugins is
unique to my knowledge. If anyone knows another way that plugins are
communicating over HTTP then let me know.

A request that returns a C<5xx> status will automatically return as CRITICAL
and the plugin will display the error code and the status message (this will
typically result in C<500 Internal Server Error>).

A request that returns a C<2xx> status will be parsed using the methods listed
in L</HTTP BODY> and L</HTTP HEADER>.

If the response results is a redirect, the L</useragent> will automatically
redirect the response and all processing will ultimately be done on the final
response. Any other status code will cause the plugin to return as UNKNOWN and
the plugin will display the error code and the status message.

=head2 HTTP BODY

The body of the HTTP response will be the output of the plugin unless the
header L</X-Nagios-Information> is present. To determine what the status code
will be, the following methods are used:

=over 4

=item 1.

If a the header C<X-Nagios-Status> is present, the value from that is used as
the output. See L</X-Nagios-Status>.

=item 2.

If the header was not present, then the status will be extracted from the body
of the response. The very first set of all capital letters is taken from the
body and used to determine the result. The different possibilities for this is
listed in L</NAGIOS STATUSES>.

=back

=head2 HTTP HEADER

The following HTTP headers have special meanings:

=head3 C<< X-Nagios-Information >>

B<Added in version 0.12>; be sure to require this version for this feature.

If this header is present, then the content of this header will be used as the
message for the plugin. Note: B<the body will not be parsed>. This is meant as
an indication that the Nagios output is solely contained in the headers. This
MUST contain the message ONLY. If this header appears multiple times, each
instance is appended together with line breaks in the same order for multiline
plugin output support.

  X-Nagios-Information: Connection to database succeeded
  X-Nagios-Information: 'www'@'localhost'

=head3 C<< X-Nagios-Performance >>

B<Added in version 0.14>; be sure to require this version for this feature.

This header specifies various performance data from the plugin. This will add
performance to the list of any data collected from the response body as
specified in L</HTTP BODY>. Many performance data may be contained in a single
header seperated by spaces any many headers may be specified.

  X-Nagios-Performance: 'connect time'=0.0012s

=head3 C<< X-Nagios-Status >>

This header specifies the status. When this header is specified, then this is
will override any other location where the status can come from. The content of
this header MUST be either the decimal return value of the plugin or the status
name in all capital letters. The different possibilities for this is listed in
L</NAGIOS STATUSES>. If the header appears more than once, the first occurance
is used.

  X-Nagios-Status: OK

=head2 NAGIOS STATUSES

=over 4

=item 0 OK

C<< $Nagios::Plugin::OverHTTP::STATUS_OK >>

=item 1 WARNING

C<< $Nagios::Plugin::OverHTTP::STATUS_WARNING >>

=item 2 CRITICAL

C<< $Nagios::Plugin::OverHTTP::STATUS_CRITICAL >>

=item 3 UNKNOWN

C<< $Nagios::Plugin::OverHTTP::STATUS_UNKNOWN >>

=back

=head2 EXAMPLE

The following is an example of a simple bootstrapping of a plugin on a remote
server.

  #!/usr/bin/env perl

  use strict;
  use warnings;

  my $output = qx{/usr/local/libexec/nagios/check_users2 -w 100 -c 500};

  my $status = $? > 0 ? $? >> 8 : 3;

  printf "X-Nagios-Status: %d\n", $status;
  print  "Content-Type: text/plain\n\n";
  print  $output if $output;

  exit 0;

=head1 DEPENDENCIES

=over 4

=item * L<Carp>

=item * L<HTTP::Request> 5.827

=item * L<HTTP::Status> 5.817

=item * L<LWP::UserAgent>

=item * L<Moose> 0.74

=item * L<MooseX::Getopt> 0.19

=item * L<MooseX::StrictConstructor> 0.08

=item * L<Readonly> 1.03

=item * L<URI>

=item * L<namespace::clean> 0.04

=back

=head1 AUTHOR

Douglas Christopher Wilson, C<< <doug at somethingdoug.com> >>

=head1 ACKNOWLEDGEMENTS

=over

=item * Alex Wollangk contributed the idea and code for the
L</X-Nagios-Information> header.

=back

=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
C<bug-nagios-plugin-overhttp at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Nagios-Plugin-OverHTTP>. I
will be notified, and then you'll automatically be notified of progress on your
bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

  perldoc Nagios::Plugin::OverHTTP

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Nagios-Plugin-OverHTTP>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Nagios-Plugin-OverHTTP>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Nagios-Plugin-OverHTTP>

=item * Search CPAN

L<http://search.cpan.org/dist/Nagios-Plugin-OverHTTP/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2009-2010 Douglas Christopher Wilson, all rights reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back
