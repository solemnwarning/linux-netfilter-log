=head1 NAME

Linux::Netfilter::Log - Read packets logged using the C<NFLOG> mechanism

=head1 SYNOPSIS

...

=head1 DESCRIPTION

...

=head1 CONSTANTS

The C<libnetfilter_log> constants may be imported from this module individually
or using the C<:constants> import tag.

=cut

use strict;
use warnings;

package Linux::Netfilter::Log;

use Exporter qw(import);

use Linux::Netfilter::Log::Constants;
use Linux::Netfilter::Log::Group;
use Linux::Netfilter::Log::Packet;

require XSLoader;
XSLoader::load("Linux::Netfilter::Log");

# Our @EXPORT_OK gets initialised by the ::Constants module.
our @EXPORT_OK;
our %EXPORT_TAGS = (
	constants => [ @EXPORT_OK ],
);

=head1 CLASS METHODS

=head2 open()

Constructor. Sets up an nflog handle and underlying netlink socket.

=head1 INSTANCE METHODS

=head2 bind_pf(protocol_family)

Binds the given nflog handle to process packets belonging to the given protocol
family (ie. PF_INET, PF_INET6, etc).

=head2 unbind_pf(protocol_family)

Unbinds the given nflog handle from processing packets belonging to the given
protocol family.

=head2 fileno()

Returns the file descriptor of the underlying netlink socket, for polling with
C<select> or similar.

=head1 SEE ALSO

L<Linux::Netfilter::Log::Group>

=head1 AUTHOR

Daniel Collins E<lt>daniel.collins@smoothwall.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 L<Smoothwall Ltd.|http://www.smoothwall.com/>

This library is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
