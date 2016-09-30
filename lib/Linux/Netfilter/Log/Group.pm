=head1 NAME

Linux::Netfilter::Log::Group - Recieve packets for a particular C<NFLOG> group.

=head1 DESCRIPTION

...

=cut

use strict;
use warnings;

package Linux::Netfilter::Log::Group;

require XSLoader;
XSLoader::load("Linux::Netfilter::Log::Group");

=head1 CLASS METHODS

=head2 bind_group($log, $group)

Constructor. Takes a reference to a L<Linux::Netfilter::Log> object and the
group number to bind to.

=head1 INSTANCE METHODS

=head2 callback_register($callback)

Sets the callback subroutine used to process packets logged in this group.

  $group->callback_register(sub
  {
	  my ($packet) = @_;
	  
	  ...
	  
	  return 0; # Success
  });

The C<$packet> is a L<Linux::Netfilter::Log::Packet> reference. The callback
must return an integer that is greater than or equal to zero, zero being used
to indicate the callback's processing was successful. The callback's return
value will be returned by TODO: handle_packet

=head2 set_mode($mode, $range)

...

=head2 set_nlbufsiz($size)

...

=head2 set_qthresh($qthresh)

...

=head2 set_timeout($timeout)

...

=head1 SEE ALSO

L<Linux::Netfilter::Log>, L<Linux::Netfilter::Log::Packet>

=cut

1;
