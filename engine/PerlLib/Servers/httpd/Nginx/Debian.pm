=head1 NAME

 Servers::httpd::Nginx::Debian - i-MSCP (Debian) Nginx server implementation

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

package Servers::httpd::Nginx::Debian;

use strict;
use warnings;
use Class::Autouse qw/ :nostat Servers::httpd /;
use Cwd qw/ realpath /;
use File::Basename;
use File::Spec;
use iMSCP::Debug qw/ debug error /;
use iMSCP::Dir;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Service;
use parent $main::imscpConfig{'HTTPD_PACKAGE'}, 'Servers::httpd::Interface';

=head1 DESCRIPTION

 i-MSCP (Debian) Nginx server implementation.

=head1 PUBLIC METHODS

=over 4

=item install( )

 Process install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
    my ($self) = @_;

    my $rs ||= $self->SUPER::install();
    $rs ||= $self->_makeDirs();
    $rs ||= $self->_setupModules();
    $rs ||= $self->_configure();
    $rs ||= $self->_installLogrotate();
    $rs ||= $self->_cleanup();
}

=item postinstall( )

 Process postinstall tasks

 Return int 0 on success, other on failure

=cut

sub postinstall
{
    my ($self) = @_;

    eval { iMSCP::Service->getInstance()->enable( 'nginx' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->register(
        'beforeSetupRestartServices',
        sub {
            push @{$_[0]}, [ sub { $self->start(); }, 'Nginx' ];
            0;
        },
        3
    );
}

=item uninstall( )

 Process uninstall tasks

 Return int 0 on success, other on failure

=cut

sub uninstall
{
    my ($self) = @_;

    my $rs = $self->_removeDirs();
    $rs ||= $self->_restoreDefaultConfig();
    $rs ||= $self->SUPER::uninstall();
}

=item enableSites( @sites )

 See Servers::httpd::Interface::enableSites()

=cut

sub enableSites
{
    my ($self, @sites) = @_;

    for my $site( @sites ) {
        my $target = File::Spec->canonpath( "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$site" );
        my $symlink = File::Spec->canonpath( $self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'} . '/' . basename( $site, '.conf' ));

        unless ( -f $target ) {
            error( sprintf( "Site `%s` doesn't exist", $site ));
            return 1;
        }

        next if -l $symlink && realpath( $symlink ) eq $target;

        if ( -e _ ) {
            unless ( unlink( $symlink ) ) {
                error( sprintf( "Couldn't unlink the %s file: %s", $! ));
                return 1;
            }
        }

        unless ( symlink( File::Spec->abs2rel( $target, $self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'} ), $symlink ) ) {
            error( sprintf( "Couldn't enable the `%s` site: %s", $site, $! ));
            return 1;
        }

        $self->{'reload'} ||= 1;
    }
}

=item disableSites( @sites )

 See Servers::httpd::Interface::disableSites()

=cut

sub disableSites
{
    my ($self, @sites) = @_;

    for my $site( @sites ) {
        my $symlink = File::Spec->canonpath( $self->{'config'}->{'HTTPD_SITES_ENABLED_DIR'} . '/' . basename( $site, '.conf' ));

        next unless -e $symlink;

        unless ( unlink( $symlink ) ) {
            error( sprintf( "Couldn't unlink the %s file: %s", $! ));
            return 1;
        }

        $self->{'reload'} ||= 1;
    }
}

=item enableModules( @modules )

 See Servers::httpd::Interface::enableModules()

=cut

sub enableModules
{
    my ($self, @modules) = @_;

    for my $module( @modules ) {
        my $target = File::Spec->canonpath( "$self->{'config'}->{'HTTPD_MODS_AVAILABLE_DIR'}/$module" );
        my $symlink = File::Spec->canonpath( $self->{'config'}->{'HTTPD_MODS_ENABLED_DIR'} . '/' . basename( $module, '.conf' ));

        unless ( -f $target ) {
            error( sprintf( "Module `%s` doesn't exist", $module ));
            return 1;
        }

        next if -l $symlink && realpath( $symlink ) eq $target;

        if ( -e _ ) {
            unless ( unlink( $symlink ) ) {
                error( sprintf( "Couldn't unlink the %s file: %s", $! ));
                return 1;
            }
        }

        unless ( symlink( File::Spec->abs2rel( $target, $self->{'config'}->{'HTTPD_MODS_ENABLED_DIR'} ), $symlink ) ) {
            error( sprintf( "Couldn't enable the `%s` module: %s", $module, $! ));
            return 1;
        }

        $self->{'restart'} ||= 1;
    }
}

=item disableModules( @modules )

 See Servers::httpd::Interface::disableModules()

=cut

sub disableModules
{
    my ($self, @modules) = @_;

    for my $module( @modules ) {
        my $symlink = File::Spec->canonpath( $self->{'config'}->{'HTTPD_MODS_ENABLED_DIR'} . '/' . basename( $module, '.conf' ));
        next unless -e $symlink;

        unless ( unlink( $symlink ) ) {
            error( sprintf( "Couldn't unlink the %s module: %s", $! ));
            return 1;
        }

        $self->{'restart'} ||= 1;
    }
}

=item enableConfs( @conffiles )

 See Servers::httpd::Interface::enableConfs()

=cut

sub enableConfs
{
    my ($self, @conffiles) = @_;

    0;
}

=item disableConfs( @conffiles )

 See Servers::httpd::Interface::disableConfs()

=cut

sub disableConfs
{
    my ($self, @conffiles) = @_;

    0;
}

=item start( )

 See Servers::httpd::Interface::start()

=cut

sub start
{
    my ($self) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNginxStart' );
    return $rs if $rs;

    eval { iMSCP::Service->getInstance()->start( 'nginx' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->trigger( 'afterNginxStart' );
}

=item stop( )

 See Servers::httpd::Interface::stop()

=cut

sub stop
{
    my ($self) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNginxStop' );
    return $rs if $rs;

    eval { iMSCP::Service->getInstance()->stop( 'nginx' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->trigger( 'afterNginxStop' );
}

=item restart( )

 See Servers::httpd::Interface::restart()

=cut

sub restart
{
    my ($self) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNginxRestart' );
    return $rs if $rs;

    eval { iMSCP::Service->getInstance()->restart( 'nginx' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->trigger( 'afterNginxRestart' );
}

=item reload( )

 See Servers::httpd::Interface::reload()

=cut

sub reload
{
    my ($self) = @_;

    my $rs = $self->{'eventManager'}->trigger( 'beforeNginxReload' );
    return $rs if $rs;

    eval { iMSCP::Service->getInstance()->reload( 'nginx' ); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    $self->{'eventManager'}->trigger( 'afterNginxReload' );
}

=back

=head1 PRIVATE METHODS

=over 4

=item _setVersion( )

 Servers::httpd::Interface

=cut

sub _setVersion
{
    my ($self) = @_;

    my $rs = execute( '/usr/sbin/nginx -v', \ my $stdout, \ my $stderr );
    debug( $stdout ) if $stdout;
    error( $stderr || 'Unknown error' ) if $rs;
    return $rs if $rs;

    if ( $stderr !~ m%nginx/([\d.]+)% ) {
        error( "Couldn't guess Nginx version" );
        return 1;
    }

    $self->{'config'}->{'HTTPD_VERSION'} = $1;
    debug( sprintf( 'Nginx version set to: %s', $1 ));
    0;
}

=item _makeDirs( )

 Create directories

 Return int 0 on success, other on failure

=cut

sub _makeDirs
{
    my ($self) = @_;

    eval {
        iMSCP::Dir->new( dirname => $self->{'config'}->{'HTTPD_LOG_DIR'} )->make( {
            user  => $main::imscpConfig{'ROOT_USER'},
            group => $main::imscpConfig{'ADM_GROUP'},
            mode  => 0750
        } );
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }
}

=item _setupModules( )

 Setup Nginx modules

 return 0 on success, other on failure
=cut

sub _setupModules
{
    my ($self) = @_;

    0;
}

=item _configure( )

 Configure Nginx

 Return int 0 on success, other on failure

=cut

sub _configure
{
    my ($self) = @_;

    my $rs = $self->{'eventManager'}->registerOne(
        'beforeNginxBuildConfFile',
        sub {
            my ($cfgTpl) = @_;
            ${$cfgTpl} =~ s/^NameVirtualHost[^\n]+\n//gim;
            0;
        }
    );
    $rs ||= $self->buildConfFile( "$self->{'config'}->{'HTTPD_CONF_DIR'}/ports.conf", "$self->{'config'}->{'HTTPD_CONF_DIR'}/ports.conf" );

    # Turn off default access log provided by Debian package
    $rs = $self->disableConfs( 'other-vhosts-access-log.conf' );
    return $rs if $rs;

    # Remove default access log file provided by Debian package
    if ( -f "$self->{'config'}->{'HTTPD_LOG_DIR'}/other_vhosts_access.log" ) {
        $rs = iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_LOG_DIR'}/other_vhosts_access.log" )->delFile();
        return $rs if $rs;
    }

    my $serverData = {
        HTTPD_CUSTOM_SITES_DIR => $self->{'config'}->{'HTTPD_CUSTOM_SITES_DIR'},
        HTTPD_LOG_DIR          => $self->{'config'}->{'HTTPD_LOG_DIR'},
        HTTPD_ROOT_DIR         => $self->{'config'}->{'HTTPD_ROOT_DIR'},
        VLOGGER_CONF           => "$self->{'cfgDir'}/vlogger.conf"
    };

    $rs = $self->buildConfFile( '00_nameserver.conf', "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_nameserver.conf", undef, $serverData );
    $rs ||= $self->enableSites( '00_nameserver.conf' );
    $rs ||= $self->buildConfFile( '00_imscp.conf', "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf-available/00_imscp.conf", undef, $serverData );
    $rs ||= $self->enableConfs( '00_imscp.conf' );
    $rs ||= $self->disableSites( 'default', 'default-ssl', '000-default.conf', 'default-ssl.conf' );
}

=item _installLogrotate( )

 Install Apache logrotate file

 Return int 0 on success, other on failure

=cut

sub _installLogrotate
{
    my ($self) = @_;

    $self->buildConfFile(
        'logrotate.conf',
        "$main::imscpConfig{'LOGROTATE_CONF_DIR'}/nginx",
        undef,
        {
            ROOT_USER     => $main::imscpConfig{'ROOT_USER'},
            ADM_GROUP     => $main::imscpConfig{'ADM_GROUP'},
            HTTPD_LOG_DIR => $self->{'config'}->{'HTTPD_LOG_DIR'}
        }
    );
}

=item _cleanup( )

 Process cleanup tasks

 Return int 0 on success, other on failure

=cut

sub _cleanup
{
    my ($self) = @_;

    0;
}

=item _removeDirs( )

 Remove non-default Nginx directories

 Return int 0 on success, other on failure

=cut

sub _removeDirs
{
    my ($self) = @_;

    eval { iMSCP::Dir->new( dirname => $self->{'config'}->{'HTTPD_CUSTOM_SITES_DIR'} )->remove(); };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    0;
}

=item _restoreDefaultConfig( )

 Restore default Nginx configuration

 Return int 0 on success, other on failure

=cut

sub _restoreDefaultConfig
{
    my ($self) = @_;

    if ( -f "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_nameserver.conf" ) {
        my $rs = $self->disableSites( '00_nameserver.conf' );
        $rs ||= iMSCP::File->new( filename => "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_nameserver.conf" )->delFile();
        return $rs if $rs;
    }

    my $confDir = -d "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf-available"
        ? "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf-available" : "$self->{'config'}->{'HTTPD_CONF_DIR'}/conf.d";

    if ( -f "$confDir/00_imscp.conf" ) {
        my $rs = $self->disableConfs( '00_imscp.conf' );
        $rs ||= iMSCP::File->new( filename => "$confDir/00_imscp.conf" )->delFile();
        return $rs if $rs;
    }

    eval {
        for ( glob( "$main::imscpConfig{'USER_WEB_DIR'}/*/domain_disable_page" ) ) {
            iMSCP::Dir->new( dirname => $_ )->remove();
        }

        iMSCP::Dir->new( dirname => $self->{'config'}->{'HTTPD_CUSTOM_SITES_DIR'} )->remove();
    };
    if ( $@ ) {
        error( $@ );
        return 1;
    }

    for ( '000-default', 'default' ) {
        next unless -f "$self->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$_";
        my $rs = $self->enableSites( $_ );
        return $rs if $rs;
    }

    0;
}

=back

=head1 SHUTDOWN TASKS

=over 4

=item END

 Schedule restart, reload or start of httpd server when needed

=cut

END
    {
        return if $? || ( defined $main::execmode && $main::execmode eq 'setup' );

        my $instance = __PACKAGE__->hasInstance();

        return unless $instance && ( my $action = $instance->{'restart'}
            ? 'restart' : ( $instance->{'reload'} ? 'reload' : ( $instance->{'start'} ? ' start' : undef ) ) );

        iMSCP::Service->getInstance()->registerDelayedAction(
            'nginx', [ $action, sub { $instance->$action(); } ], Servers::httpd::getPriority()
        );
    }

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
