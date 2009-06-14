package Nagios::Plugin::OverHTTP::Library;

use 5.008001;
use strict;
use utf8;
use version 0.74;
use warnings 'all';

# Module metadata
our $AUTHORITY = 'cpan:DOUGDUDE';
our $VERSION = '0.08';

use MooseX::Types 0.08 -declare => [qw(
	Hostname
	Path
	Timeout
	URL
)];

use Data::Validate::Domain 0.02;
use Data::Validate::URI 0.05;

# Import built-in types
use MooseX::Types::Moose qw(Int Str);

# Type definitions
subtype Hostname,
	as Str,
	where { Data::Validate::Domain::is_hostname($_) },
	message { 'Must be a valid hostname' };

subtype Path,
	as Str,
	where { m{\A /}msx; },
	message { 'Must be a valid URL path' };

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

1;

__END__

=encoding utf8

=head1 NAME

Nagios::Plugin::OverHTTP::Library - Types library

=head1 VERSION

This documentation refers to <Nagios::Plugin::OverHTTP::Library> version 0.08

=head1 SYNOPSIS

  use Nagios::Plugin::OverHTTP::Library qw(URL);
  # This will import URL type into your namespace as well as some helpers
  # like to_URL and is_URL. See MooseX::Types for more information.

=head1 DESCRIPTION

This module provides types for Nagios::Plugin::OverHTTP

=head1 METHODS

No methods.

=head1 TYPES PROVIDED

=over 4

=item * Hostname

=item * Path

=item * Timeout

=item * URL

=back

=head1 DEPENDENCIES

This module is dependent on the following modules:

=over 4

=item * L<Data::Validate::Domain> 0.02

=item * L<Data::Validate::URI> 0.05

=item * L<MooseX::Types> 0.08

=back

=head1 AUTHOR

Douglas Christopher Wilson, C<< <doug at somethingdoug.com> >>

=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
C<bug-authen-cas-external at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Authen-CAS-External>. I will
be notified, and then you'll automatically be notified of progress on your bug
as I make changes.

=head1 LICENSE AND COPYRIGHT

Copyright 2009 Douglas Christopher Wilson, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
