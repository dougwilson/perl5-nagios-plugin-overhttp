package Nagios::Plugin::OverHTTP;

use 5.008001;
use strict;
use utf8;
use version 0.74;
use warnings 'all';

# Module metadata
our $AUTHORITY = 'cpan:DOUGDUDE';
our $VERSION = '0.01';

use Carp ();
use LWP::UserAgent ();
use Moose 0.74;
use MooseX::StrictConstructor 0.08;
use Readonly;
use Switch qw(switch);

with 'MooseX::Getopt';

# Constants
Readonly our $STATUS_OK       => 0;
Readonly our $STATUS_WARNING  => 1;
Readonly our $STATUS_CRITICAL => 2;
Readonly our $STATUS_UNKNOWN  => 3;

# Attributes

has 'message' => (
	is            => 'ro',
	isa           => 'Str',
	builder       => '_build_message',
	clearer       => '_clear_message',
	lazy          => 1,
	predicate     => 'has_message',
	traits        => ['NoGetopt'],
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
	isa           => 'Str',
	required      => 1,
	documentation => q{The URL to the remote nagios plugin},
	trigger       => sub { shift->_clear_state; },
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

	# Get the response of the plugin
	my $response = $self->useragent->get($self->url);

	if ($response->code =~ m{\A5}msx) {
		# There was some type of internal error
		$self->_set_state($STATUS_CRITICAL, sprintf '%d %s', $response->code, $response->message);
		return;
	}
	elsif (!$response->is_success) {
		# The response was not a success
		$self->_set_state($STATUS_UNKNOWN, sprintf '%d %s', $response->code, $response->message);
		return;
	}

	my %status_prefix_map = (
		OK       => $STATUS_OK,
		WARNING  => $STATUS_WARNING,
		CRITICAL => $STATUS_CRITICAL,
		UNKNOWN  => $STATUS_UNKNOWN,
	);

	# By default we do not know the status
	my $status = $STATUS_UNKNOWN;
	my $status_header = $response->header('X-Nagios-Status');

	if (defined $status_header && exists $status_prefix_map{$status_header}) {
		# Get the status from the header if present
		$status = $status_prefix_map{$status_header};
	}
	elsif (my ($inc_status) = $response->decoded_content =~ m{\A([A-Z]+)}msx) {
		if (exists $status_prefix_map{$inc_status}) {
			$status = $status_prefix_map{$inc_status};
		}
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

sub _build_message {
	my ($self) = @_;

	# Preform the check
	$self->check;

	return $self->{message};
}

sub _build_status {
	my ($self) = @_;

	# Preform the check
	$self->check;

	return $self->{status};
}

sub _clear_state {
	my ($self) = @_;

	$self->_clear_message;
	$self->_clear_status;

	return;
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

	return;
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

Version 0.01

=head1 SYNOPSIS

  my $plugin = Nagios::Plugin::OverHTTP->new(
      url => 'https://myserver.net/nagios/check_some_service.cgi',
  );

  my $status  = $plugin->status;
  my $message = $plugin->message;

=head1 DESCRIPTION

This Nagios plugin provides a way to check services remotely over the HTTP
protocol.

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

=head1 DEPENDENCIES

=over 4

=item * L<Carp>

=item * L<Moose> 0.74

=item * L<MooseX::Getopt>

=item * L<MooseX::StrictConstructor> 0.08

=back

=head1 AUTHOR

Douglas Christopher Wilson, C<< <doug at somethingdoug.com> >>

=head1 BUGS AND LIMITATIONS

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
