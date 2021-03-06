=head1 NAME

 iMSCP::EventManager - i-MSCP Event Manager

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

package iMSCP::EventManager;

use strict;
use warnings;
use iMSCP::Debug qw/ debug error getMessageByType /;
use iMSCP::PriorityQueue;
use Scalar::Util qw / blessed refaddr /;
use parent 'iMSCP::Common::SingletonClass';

=head1 DESCRIPTION

 The i-MSCP event manager is the central point of the event system.

 Event listeners are registered on the event manager and events are triggered through the event manager. Event
 listeners are references to subroutines that listen to particular event(s).

=head1 PUBLIC METHODS

=over 4

=item hasListener( $eventName, $listener )

 Is the given listener registered for the given event?

 Param string $eventName Event name on which $listener listen on
 Param coderef $listener A CODE reference
 Return bool TRUE if the given event has the given listener, FALSE otherwise, die on failure

=cut

sub hasListener
{
    my ($self, $eventName, $listener) = @_;

    defined $eventName or die 'Missing $eventName parameter';
    ref $listener eq 'CODE' or die 'Missing or invalid $listener parameter';

    exists $self->{'events'}->{$eventName} && $self->{'events'}->{$eventName}->hasItem( $listener );
}

=item register( $eventNames, $listener [, priority = 0 [, $once = FALSE ] ] )

 Registers an event listener for the given events

 Param string|arrayref $eventNames Event(s) that the listener listen to
 Param coderef|object $listener A CODE reference or an object implementing $eventNames method
 Param int $priority OPTIONAL Listener priority (Highest values have highest priority)
 Param bool $once OPTIONAL If TRUE, $listener will be executed at most once for the given events
 Return int 0 on success, 1 on failure

=cut

sub register
{
    my ($self, $eventNames, $listener, $priority, $once) = @_;

    eval {
        defined $eventNames or die 'Missing $eventNames parameter';

        if ( ref $eventNames eq 'ARRAY' ) {
            for ( @{$eventNames} ) {
                $self->register( $_, $listener, $priority, $once ) == 0 or die(
                    getMessageByType( 'error', { amount => 1, remove => 1 } ) || 'Unknown error'
                );
            }

            return;
        }

        ( ref $listener eq 'CODE' || blessed $listener ) or die(
            'Invalid $listener parameter. Expects an object or code reference.'
        );

        ( $self->{'events'}->{$eventNames} //= iMSCP::PriorityQueue->new() )->addItem( $listener, $priority );
        $self->{'nonces'}->{$eventNames}->{$listener}++ if $once;
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item registerOne( $eventNames, $listener [, priority = 0 ] )

 Registers an event listener that will be executed at most once for the given events
 
 This is shortcut method for ::register( $eventNames, $listener, $priority, $once )

 Param string|arrayref $eventNames Event(s) that the listener listen to
 Param coderef|object $listener A CODE reference or object implementing $eventNames method
 Param int $priority OPTIONAL Listener priority (Highest values have highest priority)
 Return int 0 on success, 1 on failure

=cut

sub registerOne
{
    my ($self, $eventNames, $listener, $priority) = @_;

    $self->register( $eventNames, $listener, $priority, 1 );
}

=item unregister( $listener [, $eventName = $self->{'events'} ] )

 Unregister the given listener from all or the given event

 Param coderef $listener Listener
 Param string OPTIONAL $eventName Event name
 Return int 0 on success, 1 on failure

=cut

sub unregister
{
    my ($self, $listener, $eventName) = @_;

    eval {
        ref $listener eq 'CODE' or die 'Missing or invalid $listener parameter';

        if ( defined $eventName ) {
            return unless exists $self->{'events'}->{$eventName};

            $self->{'events'}->{$eventName}->removeItem( $listener );

            if ( $self->{'events'}->{$eventName}->isEmpty() ) {
                delete $self->{'events'}->{$eventName};
                delete $self->{'nonces'}->{$eventName};
                return;
            }

            if ( delete $self->{'nonces'}->{$eventName}->{$listener} ) {
                delete $self->{'nonces'}->{$eventName} unless %{$self->{'nonces'}->{$eventName}};
            }

            return;
        }

        $self->unregister( $listener, $_ ) for keys %{$self->{'events'}};
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item clearListeners( $eventName )

 Clear all listeners for the given event

 Param string $event Event name
 Return int 0 on success, 1 on failure

=cut

sub clearListeners
{
    my ($self, $eventName) = @_;

    unless ( defined $eventName ) {
        error( 'Missing $eventName parameter' );
        return 1;
    }

    delete $self->{'events'}->{$eventName} if exists $self->{'events'}->{$eventName};
    delete $self->{'nonces'}->{$eventName} if exists $self->{'nonces'}->{$eventName};
    0;
}

=item trigger( $eventName [, @params ] )

 Triggers the given event

 Param string $eventName Event name
 Param mixed @params OPTIONAL parameters passed-in to the listeners
 Return int 0 on success, other on failure

=cut

sub trigger
{
    my ($self, $eventName, @params) = @_;

    unless ( defined $eventName ) {
        error( 'Missing $eventName parameter' );
        return 1;
    }

    return 0 unless exists $self->{'events'}->{$eventName};

    debug( sprintf( 'Triggering %s event', $eventName ));

    # The priority queue acts as a heap, which implies that as items are popped
    # they are also removed. Thus we clone it (in surface) for purposes of iteration.
    my ($rs, $priorityQueue) = ( 0, $self->{'events'}->{$eventName}->clone() );
    while ( my $listener = $priorityQueue->pop ) {
        $rs = blessed $listener ? $listener->$eventName( @params ) : $listener->( @params );
        last if $rs;

        if ( $self->{'nonces'}->{$eventName}->{$listener} ) {
            $self->{'events'}->{$eventName}->removeItem( $listener );
            delete $self->{'nonces'}->{$eventName}->{$listener} if --$self->{'nonces'}->{$eventName}->{$listener} < 1;
        }
    }

    # We must test for priority queue existence here too because a listener can self-unregister
    if ( exists $self->{'events'}->{$eventName} && $self->{'events'}->{$eventName}->isEmpty() ) {
        delete $self->{'events'}->{$eventName};
        delete $self->{'nonces'}->{$eventName};
        return $rs;
    }

    delete $self->{'nonces'}->{$eventName} if $self->{'nonces'}->{$eventName} && !%{$self->{'nonces'}->{$eventName}};
    $rs;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::EventManager

=cut

sub _init
{
    my ($self) = @_;

    $self->{'events'} = {};
    $self->{'nonces'} = {};

    while ( <$main::imscpConfig{'CONF_DIR'}/listeners.d/*.pl> ) {
        debug( sprintf( 'Loading %s listener file', $_ ));
        require $_;
    }

    $self;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
