package Nagios::Plugin::OverHTTP;

use 5.008001;
use strict;
use utf8;
use version 0.74;
use warnings 'all';

# Module metadata
our $AUTHORITY = 'cpan:DOUGDUDE';
our $VERSION = '0.08';

use Carp ();
use HTTP::Status qw(:constants);
use LWP::UserAgent ();
use Moose 0.74;
use MooseX::StrictConstructor 0.08;
use Nagios::Plugin::OverHTTP::Library qw(
	Hostname
	Path
	Timeout
	URL
);
use Readonly;
use URI;

with 'MooseX::Getopt';

# Constants
Readonly our $STATUS_OK       => 0;
Readonly our $STATUS_WARNING  => 1;
Readonly our $STATUS_CRITICAL => 2;
Readonly our $STATUS_UNKNOWN  => 3;

# Attributes

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
	isa           => 'Int',

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

sub check {
	my ($self) = @_;

	# Save the current timeout for the useragent
	my $old_timeout = $self->useragent->timeout;

	# Set the useragent's timeout to our timeout
	# if a timeout has been declared.
	if ($self->has_timeout) {
		$self->useragent->timeout($self->timeout);
	}

	# Get the response of the plugin
	my $response = $self->useragent->get($self->url);

	# Restore the previous timeout value to the useragent
	$self->useragent->timeout($old_timeout);

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

	my %status_prefix_map = (
		OK       => $STATUS_OK,
		WARNING  => $STATUS_WARNING,
		CRITICAL => $STATUS_CRITICAL,
		UNKNOWN  => $STATUS_UNKNOWN,
	);

	# By default we do not know the status
	my $status;
	my $status_header = $response->header('X-Nagios-Status');

	if (defined $status_header) {
		# Get the status from the header if present
		if ($status_header =~ m{\A [0123] \z}msx) {
			# The status header is the decimal status
			$status = $status_header;
		}
		elsif (exists $status_prefix_map{$status_header}) {
			# The status header is the word of the status
			$status = $status_prefix_map{$status_header};
		}
	}
	elsif (my ($inc_status) = $response->decoded_content =~ m{\A([A-Z]+)}msx) {
		if (exists $status_prefix_map{$inc_status}) {
			$status = $status_prefix_map{$inc_status};
		}
	}

	if (!defined $status) {
		# The status was not found in the response
		$status = $STATUS_UNKNOWN;
	}

	$self->_set_state($status, $response->decoded_content);
	return;
}

sub run {
	my ($self) = @_;

	# Print the message to stdout
	print $self->message;

	# Return the status code
	return $self->status;
}

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
		Carp::croak 'Unable to build the URL due to no hostname being provided';
	}
	elsif (!$self->_has_path) {
		Carp::croak 'Unable to build the URL due to no path being provided.';
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

sub _populate_from_url {
	my ($self) = @_;

	if (!$self->_has_url) {
		Carp::croak 'Unable to build requested attributes, as no URL as been defined';
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

# Make immutable
__PACKAGE__->meta->make_immutable;

# Clean out Moose keywords
no Moose;

1;

__END__

=head1 NAME

Nagios::Plugin::OverHTTP - Nagios plugin to check over the HTTP protocol.

=head1 VERSION

Version 0.08

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

=head3 hostname

This is the hostname of the remote server. This will automatically be populated
if L</url> is set.

=head3 path

This is the path to the remove Nagios plugin on the remote server. This will
automatically be populated if L</url> is set.

=head3 ssl

This is a Boolean of whether or not to use SSL over HTTP (HTTPS). This defaults
to false and will automatically be updated to true if a HTTPS URL is set to
L</url>.

=head3 timeout

This is a positive integer for the timeout of the HTTP request. If set, this
will override any timeout defined in the useragent for the duration of the
request. The plugin will not permanently alter the timeout in the useragent.
This defaults to not being set, and so the useragent's timeout is used.

=head3 url

This is the URL of the remote Nagios plugin to check. If not supplied, this will
be constructed automatically from the L</hostname> and L</path> attributes.

=head3 useragent

This is the useragent to use when making requests. This defaults to
L<LWP::Useragent> with no options. Currently this must be an L<LWP::Useragent>
object.

=head2 new_with_options

This is identical to L</new>, except with the additional feature of reading the
C<@ARGV> in the invoked scope (NOTE: a HASHREF cannot be provided as the
constructing argument due to a bug in L<MooseX::Getopt>). C<@ARGV> will be
parsed for command-line arguments. The command-line can contain any variable
that L</new> can take. Arguments should be in the following format on the
command line:

  --url=http://example.net/check_something
  --url http://example.net/check_something
  # Note that quotes may be used, based on your shell environment

  # For bools, like SSL, you would use:
  --ssl    # Enable SSL
  --no-ssl # Disable SSL

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

The body of the HTTP response will be the output of the plugin. To determine
what the status code will be, the following methods are used:

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

=head2 NAGIOS STATUSES

=over 4

=item 0 OK

=item 1 WARNING

=item 2 CRITICAL

=item 3 UNKNOWN

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

=item * L<HTTP::Status>

=item * L<LWP::UserAgent>

=item * L<Moose> 0.74

=item * L<MooseX::Getopt>

=item * L<MooseX::StrictConstructor> 0.08

=item * L<Readonly>

=item * L<URI>

=back

=head1 AUTHOR

Douglas Christopher Wilson, C<< <doug at somethingdoug.com> >>

=head1 BUGS AND LIMITATIONS

C<new_with_options> does not support a single HASHREF argument. Waiting on fix
in L<https://rt.cpan.org/Ticket/Display.html?id=46200>.

Please report any bugs or feature requests to
C<bug-authen-cas-external at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Authen-CAS-External>. I will
be notified, and then you'll automatically be notified of progress on your bug
as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

perldoc Authen::CAS::External


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Authen-CAS-External>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Authen-CAS-External>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Authen-CAS-External>

=item * Search CPAN

L<http://search.cpan.org/dist/Authen-CAS-External/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2009 Douglas Christopher Wilson, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
