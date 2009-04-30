package Nagios::Plugin::OverHTTP;

use 5.008;
use strict;
use utf8;
use version 0.74;
use warnings 'all';

# Module metadata
our $AUTHORITY = 'cpan:DOUGDUDE';
our $VERSION = '0.01';

use Carp ();
use Getopt::Long::Descriptive 0.074 ();
use Moose 0.74;
use MooseX::StrictConstructor 0.08;
use Scalar::Util 1.19 ();

# Attributes

has 'url' => (
	is            => 'rw',
	isa           => 'Str',
	required      => 1,
	documentation => q{The URL to the remote nagios plugin},
);

sub BUILDARGS {
	my (@args) = @_;

	if (defined Scalar::Util::blessed($args[0])) {
		# Call subclass BUILDARGS first
		@args = $args[0]->SUPER::BUILDARGS(@args);
	}

	# Parse the arguments
	my ($class, $args) = @args;

	if (keys %{$args} == 0) {
		# Since there are no arguments, initiate from @ARGV
		my @attributes = $class->meta->get_all_attributes;

		# Reduce the list to not include private attributes
		@attributes = grep {$_->name !~ m{\A _}msx} @attributes;

		# Map the attributes into options
		my @options = map {[
			sprintf('%s=s', $_->name),
			$_->documentation,
		]} @attributes;

		my ($options, $usage) = Getopt::Long::Descriptive::describe_options('Usage: %c %o', @options);

		# Set the args to the parsed options
		$args = $options;
	}

	# Return the argument hash and class
	return $class, $args;
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

=head1 DEPENDENCIES

=head1 AUTHOR

Douglas Christopher Wilson, C<< <doug at somethingdoug.com> >>

=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to C<bug-authen-cas-external at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Authen-CAS-External>. I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




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
