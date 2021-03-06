=head1 NAME

 iMSCP::Modules::Htaccess - i-MSCP Htaccess module

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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

package iMSCP::Modules::Htaccess;

use strict;
use warnings;
use Encode qw/ encode_utf8 /;
use File::Spec;
use iMSCP::Debug qw/ error getLastError warning /;
use parent 'iMSCP::Modules::Abstract';

=head1 DESCRIPTION

 Module for processing of htaccess entities

=head1 PUBLIC METHODS

=over 4

=item getEntityType( )

 Get entity type

 Return string entity type

=cut

sub getEntityType
{
    'Htaccess';
}

=item process( $htaccessId )

 Process module

 Param int $htaccessId Htaccess unique identifier
 Return int 0 on success, other on failure

=cut

sub process
{
    my ($self, $htaccessId) = @_;

    my $rs = $self->_loadData( $htaccessId );
    return $rs if $rs;

    my @sql;
    if ( $self->{'status'} =~ /^to(?:add|change|enable)$/ ) {
        $rs = $self->add();
        @sql = ( 'UPDATE htaccess SET status = ? WHERE id = ?', undef, ( $rs ? getLastError( 'error' ) || 'Unknown error' : 'ok' ), $htaccessId );
    } elsif ( $self->{'status'} eq 'todisable' ) {
        $rs = $self->disable();
        @sql = (
            'UPDATE htaccess SET status = ? WHERE id = ?', undef, ( $rs ? getLastError( 'error' ) || 'Unknown error' : 'disabled' ), $htaccessId
        );
    } elsif ( $self->{'status'} eq 'todelete' ) {
        $rs = $self->delete();
        @sql = $rs
            ? ( 'UPDATE htaccess SET status = ? WHERE id = ?', undef, ( getLastError( 'error' ) || 'Unknown error' ), $htaccessId )
            : ( 'DELETE FROM htaccess WHERE id = ?', undef, $htaccessId );
    } else {
        warning( sprintf( 'Unknown action (%s) for htaccess (ID %d)', $self->{'status'}, $htaccessId ));
        return 0;
    }

    eval {
        local $self->{'_dbh'}->{'RaiseError'} = 1;
        $self->{'_dbh'}->do( @sql );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $rs;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _loadData( $htaccessId )

 Load data

 Param int $htaccessId Htaccess unique identifier
 Return int 0 on success, other on failure

=cut

sub _loadData
{
    my ($self, $htaccessId) = @_;

    eval {
        local $self->{'_dbh'}->{'RaiseError'} = 1;
        my $row = $self->{'_dbh'}->selectrow_hashref(
            "
                SELECT t3.id, t3.auth_type, t3.auth_name, t3.path, t3.status, t3.users, t3.groups,
                    t4.domain_name, t4.domain_admin_id
                FROM (SELECT * FROM htaccess, (SELECT IFNULL(
                    (
                        SELECT group_concat(uname SEPARATOR ' ')
                        FROM htaccess_users
                        WHERE id regexp (CONCAT('^(', (SELECT REPLACE((SELECT user_id FROM htaccess WHERE id = ?), ',', '|')), ')\$'))
                        GROUP BY dmn_id
                    ), '') AS users) AS t1, (SELECT IFNULL(
                        (
                            SELECT group_concat(ugroup SEPARATOR ' ')
                            FROM htaccess_groups
                            WHERE id regexp (
                                CONCAT('^(', (SELECT REPLACE((SELECT group_id FROM htaccess WHERE id = ?), ',', '|')), ')\$')
                            )
                            GROUP BY dmn_id
                        ), '') AS groups) AS t2
                    ) AS t3
                JOIN domain AS t4 ON (t3.dmn_id = t4.domain_id)
                WHERE t3.id = ?
            ",
            undef, $htaccessId, $htaccessId, $htaccessId
        );
        $row or die( sprintf( 'Data not found for htaccess (ID %d)', $htaccessId ));
        %{$self} = ( %{$self}, %{$row} );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item _getData( $action )

 Data provider method for servers and packages

 Param string $action Action
 Return hashref Reference to a hash containing data

=cut

sub _getData
{
    my ($self, $action) = @_;

    return $self->{'_data'} if %{$self->{'_data'}};

    my $usergroup = $main::imscpConfig{'SYSTEM_USER_PREFIX'} . ( $main::imscpConfig{'SYSTEM_USER_MIN_UID'}+$self->{'domain_admin_id'} );
    my $homeDir = File::Spec->canonpath( "$main::imscpConfig{'USER_WEB_DIR'}/$self->{'domain_name'}" );
    my $pathDir = File::Spec->canonpath( "$main::imscpConfig{'USER_WEB_DIR'}/$self->{'domain_name'}/$self->{'path'}" );

    $self->{'_data'} = {
        ACTION          => $action,
        STATUS          => $self->{'status'},
        DOMAIN_ADMIN_ID => $self->{'domain_admin_id'},
        USER            => $usergroup,
        GROUP           => $usergroup,
        AUTH_TYPE       => $self->{'auth_type'},
        AUTH_NAME       => encode_utf8( $self->{'auth_name'} ),
        AUTH_PATH       => $pathDir,
        HOME_PATH       => $homeDir,
        DOMAIN_NAME     => $self->{'domain_name'},
        HTUSERS         => $self->{'users'},
        HTGROUPS        => $self->{'groups'}
    };
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
