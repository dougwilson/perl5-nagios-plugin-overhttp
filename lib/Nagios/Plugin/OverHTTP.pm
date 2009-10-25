package Nagios::Plugin::OverHTTP;

use 5.008001;
use strict;
use warnings 'all';

###########################################################################
# METADATA
our $AUTHORITY = 'cpan:DOUGDUDE';
our $VERSION   = '0.13';

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
# ATTRIBUTES
has 'autocorrect_unknown_html' => (
	is            => 'rw',
	isa           => 'Bool',
	documentation => q{When a multiline HTML response without a status is }
	                .q{received, this will add something meaningful to the}
	                .q{ first line},

	default       => 1,
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
	trigger       => sub {
		my ($self) = @_;

		# Clear the state
		$self->_clear_state;

		# Clear the URL
		$self->_clear_url;
	},
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
	trigger       => sub {
		my ($self) = @_;

		# Clear the state
		$self->_clear_state;

		# Clear the URL
		$self->_clear_url;
	},
);
has 'ssl' => (
	is            => 'rw',
	isa           => 'Bool',
	documentation => q{Whether to use SSL (defaults to no)},

	builder       => '_build_ssl',
	clearer       => '_clear_ssl',
	lazy          => 1,
	predicate     => '_has_ssl',
	trigger       => sub {
		my ($self) = @_;

		# Clear the state
		$self->_clear_state;

		# Clear the URL
		$self->_clear_url;
	},
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

###########################################################################
# METHODS
sub check {
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

	## no critic (ControlStructures::ProhibitCascadingIfElse)
	if ($response->code == HTTP_INTERNAL_SERVER_ERROR && $response->message eq 'read timeout') {
		# Failure due to timeout
		my $timeout = $self->has_timeout ? $self->timeout : $self->useragent->timeout;

		$self->_set_state($STATUS_CRITICAL, sprintf 'Socket timeout after %d seconds', $timeout);
		return;
	}
	elsif ($response->code == HTTP_INTERNAL_SERVER_ERROR && $response->message =~ m{\(connect: \s timeout\)}msx) {
		# Failure to connect to the host server
		$self->_set_state($STATUS_CRITICAL, 'Connection refused ');
		return;
	}
	elsif (HTTP::Status::is_server_error($response->code)) {
		# There was some type of internal error
		$self->_set_state($STATUS_CRITICAL, $response->status_line);
		return;
	}
	elsif (!$response->is_success) {
		# The response was not a success
		$self->_set_state($STATUS_UNKNOWN, $response->status_line);
		return;
	}

	# Get the message from the response
	my $message = $self->_extract_message_from_response($response);

	# Get the status from the response
	my $status = $self->_extract_status_from_response($response);

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

	# Set the plugin state
	$self->_set_state($status, $message);

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
sub _build_hostname {
	my ($self) = @_;

	# Build the hostname off the URL
	$self->_populate_from_url;

	return $self->{hostname};
}
sub _build_message {
	my ($self) = @_;

	# Preform the check
	$self->check;

	return $self->{message};
}
sub _build_path {
	my ($self) = @_;

	# Build the path off the URL
	$self->_populate_from_url;

	return $self->{path};
}
sub _build_ssl {
	my ($self) = @_;

	# Build the SSL off the URL
	$self->_populate_from_url;

	return $self->{ssl};
}
sub _build_status {
	my ($self) = @_;

	# Preform the check
	$self->check;

	return $self->{status};
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
sub _extract_message_from_response {
	my ($self, $response) = @_;

	my $message;

	# First priority is the X-Nagios-Information header
	if (defined $response->header('X-Nagios-Information')) {
		# Set the message
		$message = join qq{\n},
			$response->header('X-Nagios-Information');
	}
	else {
		# Otherwise the message is the body
		$message = $response->decoded_content;
	}

	# Return the message
	return $message;
}
sub _extract_status_from_response {
	my ($self, $response) = @_;

	# First priority is the X-Nagios-Status header
	my $status = to_Status($response->header('X-Nagios-Status'));

	if (!defined $status && !defined $response->header('X-Nagios-Information')) {
		# Since X-Status-Information is not present, attempt to extract it
		# from the body
		my $message = $response->decoded_content;

		if (my ($inc_status) = $message =~ m{\A ([A-Z]+)\b }msx) {
			# Attempt to get the status from the first all-caps word
			$status = to_Status($inc_status);
		}
	}

	# Return the status
	return $status;
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
# MAKE MOOSE OBJECT IMMUTABLE
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Nagios::Plugin::OverHTTP - Nagios plugin to check over the HTTP protocol.

=head1 VERSION

Version 0.13

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

  # For bools, like SSL, you would use:
  --ssl    # Enable SSL
  --no-ssl # Disable SSL

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

=head1 PROTOCOL

=head2 HTTP STATUS

The protocol that this plugin uses to communicate with the Nagios plugins is
unique to my knowledge. If anyone knows another way that plugins are
communicating over HTTP then let me know.

A request that returns a 5xx status will automatically return as CRITICAL and
the plugin will display the error code and the status message (this will
typically result in 500 Internal Server Error).

A request that returns a 2xx status will be parsed using the methods listed in
L</HTTP BODY>.

Any other status code will cause the plugin to return as UNKNOWN and the plugin
will display the error code and the status message.

=head2 HTTP BODY

The body of the HTTP response will be the output of the plugin unless the
header C<X-Nagios-Information> is present. To determine what the status code
will be, the following methods are used:

=over 4

=item 1.

If a the header C<X-Nagios-Status> is present, the value from that is used as
the output. The content of this header MUST be either the decimal return value
of the plugin or an all capital letters. The different possibilities for this
is listed in L</NAGIOS STATUSES>.

=item 2.

If the header did not conform to proper specifications or was not present, then
the status will be extracted from the body of the response. The very first set
of all capital letters is taken from the body and used to determine the result.
The different possibilities for this is listed in L</NAGIOS STATUSES>

=back

Please note that if the header C<X-Nagios-Information> is present, then the
status MUST be in the header C<X-Nagios-Status> as described above. The status
will not be extracted from any text. The C<X-Nagios-Information> header support
was added in version 0.12.

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
  
  printf "X-Nagios-Header: %d\n", $status;
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
C<X-Nagios-Information> header.

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

Copyright 2009 Douglas Christopher Wilson, all rights reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back
