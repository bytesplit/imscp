=head1 NAME

 iMSCP::Providers::Service::Debian::Upstart - Service provider for Debian `upstart' jobs.

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 by Laurent Declercq <l.declercq@nuxwin.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

package iMSCP::Providers::Service::Debian::Upstart;

use strict;
use warnings;
use parent qw/ iMSCP::Providers::Service::Upstart iMSCP::Providers::Service::Debian::Sysvinit /;

=head1 DESCRIPTION

 Service provider for Debian `upstart' jobs.

 The only differences with the base `upstart' provider are support for enabling, disabling and removing underlying
 sysvinit scripts if any.

 See: https://wiki.debian.org/Upstart

=head1 PUBLIC METHODS

=over 4

=item isEnabled( $job )

 See iMSCP::Providers::Service::Interface

=cut

sub isEnabled
{
    my ($self, $job) = @_;

    defined $job or die( 'parameter $job is not defined' );
    return $self->SUPER::isEnabled( $job ) if $self->_isUpstart( $job );
    $self->iMSCP::Providers::Service::Debian::Sysvinit::isEnabled( $job );
}

=item enable( $job )

 See iMSCP::Providers::Service::Interface

=cut

sub enable
{
    my ($self, $job) = @_;

    defined $job or die( 'parameter $job is not defined' );

    if ( $self->_isUpstart( $job ) ) {
        # Ensure that sysvinit script if any is not enabled
        # FIXME: Should we really disable underlying sysvinit script?
        #my $ret = $self->_isSysvinit( $job ) ? $self->iMSCP::Providers::Service::Debian::Sysvinit::disable( $job ) : 1;
        #return $ret && $self->SUPER::enable( $job );
        return 0 unless $self->SUPER::enable( $job );
    }

    # Also enable the underlying sysvinit script if any
    if ( $self->_isSysvinit( $job ) ) {
        return $self->iMSCP::Providers::Service::Debian::Sysvinit::enable( $job );
    }

    1;
}

=item disable( $job )

 See iMSCP::Providers::Service::Interface

=cut

sub disable
{
    my ($self, $job) = @_;

    defined $job or die( 'parameter $job is not defined' );

    if ( $self->_isUpstart( $job ) ) {
        return 0 unless $self->SUPER::disable( $job );
    }

    # Also disable the underlying sysvinit script if any
    if ( $self->_isSysvinit( $job ) ) {
        return $self->iMSCP::Providers::Service::Debian::Sysvinit::disable( $job );
    }

    1;
}

=item remove( $job )

 See iMSCP::Providers::Service::Interface

=cut

sub remove
{
    my ($self, $job) = @_;

    defined $job or die( 'parameter $job is not defined' );

    if ( $self->_isUpstart( $job ) ) {
        return 0 unless $self->SUPER::remove( $job );
    }

    # Remove the sysvinit script if any
    return $self->iMSCP::Providers::Service::Debian::Sysvinit::remove( $job ) if $self->_isSysvinit( $job );
    1;
}

=item hasService( $service )

 See iMSCP::Providers::Service::Interface

=cut

sub hasService
{
    my ($self, $service) = @_;

    defined $service or die( 'parameter $service is not defined' );

    $self->SUPER::hasService( $service ) || $self->iMSCP::Providers::Service::Debian::Sysvinit::hasService( $service );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
