package Nagios::Plugin::OverHTTP::Library;

use 5.008001;
use strict;
use warnings 'all';

# Module metadata
our $AUTHORITY = 'cpan:DOUGDUDE';
our $VERSION = '0.10';

use MooseX::Types 0.08 -declare => [qw(
	Hostname
	Path
	Status
	Timeout
	URL
)];

use Data::Validate::Domain 0.02;
use Data::Validate::URI 0.05;
use Nagios::Plugin::OverHTTP;

# Import built-in types
use MooseX::Types::Moose qw(Int Str);

# Clean the imports are the end of scope
use namespace::clean 0.04 -except => [qw(meta)];

# Type definitions
subtype Hostname,
	as Str,
	where { Data::Validate::Domain::is_hostname($_) },
	message { 'Must be a valid hostname' };

subtype Path,
	as Str,
	where { m{\A /}msx; },
	message { 'Must be a valid URL path' };

subtype Status,
	as Str,
	where { m{\A [0123] \z}msx },
	message { 'Must be between 0 and 3 inclusive' };

subtype Timeout,
	as Int,
	where { $_ > 0 && int($_) == $_ },
	message { 'Timeout must be a positive integer' };

subtype URL,
	as Str,
	where { Data::Validate::URI::is_uri($_) },
	message { 'Must be a valid URL' };

# Type coercions
coerce Path,
	from Str,
		via { m{\A /}msx ? "$_" : "/$_" };

coerce Status,
	from Str,
		via { _status_from_str($_) };

sub _status_from_str {
	my ($status_string) = @_;

	# First change the string to upper case
	$status_string = uc $status_string;

	my %status_prefix_map = (
		OK       => $Nagios::Plugin::OverHTTP::STATUS_OK,
		WARNING  => $Nagios::Plugin::OverHTTP::STATUS_WARNING,
		CRITICAL => $Nagios::Plugin::OverHTTP::STATUS_CRITICAL,
		UNKNOWN  => $Nagios::Plugin::OverHTTP::STATUS_UNKNOWN,
	);

	if (!exists $status_prefix_map{$status_string}) {
		return;
	}

	# Return the status number
	return $status_prefix_map{$status_string};
}

1;

__END__

=head1 NAME

Nagios::Plugin::OverHTTP::Library - Types library for
L<Nagios::Plugin::OverHTTP>

=head1 VERSION

This documentation refers to <Nagios::Plugin::OverHTTP::Library> version 0.10

=head1 SYNOPSIS

  use Nagios::Plugin::OverHTTP::Library qw(URL);
  # This will import URL type into your namespace as well as some helpers
  # like to_URL and is_URL. See MooseX::Types for more information.

=head1 DESCRIPTION

This module provides types for Nagios::Plugin::OverHTTP

=head1 METHODS

No methods.

=head1 TYPES PROVIDED

=head2 Hostname

This specifies a hostname. This is validated using the
L<Data::Validate::Domain> library with the C<is_hostname> function.

=head2 Path

This specifies a valid URL path. Currently this is just a string that must
begin with a forward slash. A coercion exists that will add a forward slash
to the beginning of the string if there is not one.

=head2 Status

This specifies a valid Nagios service status code. The status code must be
a valid number. This type also provides a coercion from a string. The string
is not case-sensitive and may be one of the following values:

=over 4

=item * OK

=item * WARNING

=item * CRITICAL

=item * UNKNOWN

=back

=head2 Timeout

This specifies a valid timeout value. A timeout value is an integer that is
greater than zero.

=head2 URL

This specifies a URL. This is a string and is validated using the
L<Data::Validate::URI> library with the C<is_uri> function.

=head1 DEPENDENCIES

This module is dependent on the following modules:

=over 4

=item * L<Data::Validate::Domain> 0.02

=item * L<Data::Validate::URI> 0.05

=item * L<MooseX::Types> 0.08

=item * L<namespace::clean> 0.04

=back

=head1 AUTHOR

Douglas Christopher Wilson, C<< <doug at somethingdoug.com> >>

=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
C<bug-nagios-plugin-overhttp at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Nagios-Plugin-OverHTTP>. I
will be notified, and then you'll automatically be notified of progress on your
bug as I make changes.

=head1 LICENSE AND COPYRIGHT

Copyright 2009 Douglas Christopher Wilson, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
