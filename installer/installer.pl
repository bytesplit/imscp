#!/usr/bin/perl

=head1 NAME

 installer.pl Install/Update/Reconfigure i-MSCP

=head1 SYNOPSIS

 installer [option]...

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

BEGIN { $0 = 'imscp-installer'; }

use strict;
use warnings;
use File::Basename;
use FindBin;
use lib "$FindBin::Bin/installer", "$FindBin::Bin/engine/PerlLib";
use iMSCP::Installer::Functions qw/ loadConfig build install /;
use iMSCP::Debug qw/ newDebug output /;
use iMSCP::Dialog;
use iMSCP::Getopt;
use iMSCP::Requirements;
use POSIX qw / locale_h /;

setlocale( LC_MESSAGES, "C.UTF-8" );

$ENV{'LANG'} = 'C.UTF-8';
$ENV{'PATH'} = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin';
# Needed to make any sub-process aware of i-MSCP setup process
$ENV{'IMSCP_SETUP'} = 1;

# Ensure that this script is run by root user
iMSCP::Requirements->new()->user();

newDebug( 'imscp-installer.log' );

# Set backend mode
$main::execmode = 'setup' unless defined $main::execmode;
# Init variable that holds questions
%main::questions = () unless %main::questions;
# Initialize command line options
$main::buildonly = 0;
$main::forcereinstall = 0;
$main::skippackages = 0;

# Parse installer options
iMSCP::Getopt->parse( sprintf( 'Usage: perl %s [OPTION]...', basename( $0 )) . qq {
 -b,    --build-only              Process build steps only.
 -f,    --force-reinstall         Reinstall distribution packages.
 -s,    --skip-distro-packages    Do not install/update distribution packages.},
    'build-only|b'           => \$main::buildonly,
    'force-reinstall|f'      => \$main::forcereinstall,
    'skip-distro-packages|s' => \$main::skippackages
);

# Handle preseed option
if ( iMSCP::Getopt->preseed ) {
    require iMSCP::Getopt->preseed;
    # The preseed option supersede the reconfigure option
    iMSCP::Getopt->reconfigure( 'none' );
    iMSCP::Getopt->noprompt( 1 );
}

loadConfig();

# Handle the listener option
require iMSCP::Getopt->listener if iMSCP::Getopt->listener;

if ( iMSCP::Getopt->noprompt ) {
    if ( $main::buildonly ) {
        print STDOUT output( 'Build steps in progress ... Please wait.', 'info' )
    } else {
        print STDOUT output( 'Installation in progress ... Please wait.', 'info' );
    }
}

my $ret = build();
exit $ret if $ret;
exit install() unless $main::buildonly;

iMSCP::Dialog->getInstance()->msgbox( <<"EOF" );
\\Z4\\ZuBuild Steps Successful\\Zn

To continue, you must execute the following commands:

  # rm -fR $main::imscpConfig{'ROOT_DIR'}/{daemon,engine,gui}
  # cp -fR $main::{'INST_PREF'}/* /
  # rm -fR $main::{'INST_PREF'}
  # perl $main::imscpConfig{'ROOT_DIR'}/engine/setup/imscp-reconfigure -d
EOF

END {
    return unless iMSCP::Getopt->noprompt;

    if ( $? == 5 ) {
        if ( iMSCP::Getopt->preseed ) {
            # We exit with status 5 from iMSCP::Dialog in noninteractive mode
            print STDERR output( 'Missing or bad entry found in your preseed file.', 'fatal' );
            return;
        }

        print STDERR output( 'Missing or bad entry found in configuration file.', 'fatal' );
        return;
    }

    return if $?;

    unless ( $main::buildonly ) {
        print STDOUT output( 'i-MSCP has been successfully installed/updated.', 'ok' );
        return;
    }

    print STDOUT output( 'i-MSCP has been successfully built.', 'ok' );
    print STDOUT output( <<"EOF", 'info' );
To continue, you must execute the following commands:

  # rm -fR $main::imscpConfig{'ROOT_DIR'}/{daemon,engine,gui}
  # cp -fR $main::{'INST_PREF'}/* /
  # rm -fR $main::{'INST_PREF'}
  # perl $main::imscpConfig{'ROOT_DIR'}/engine/setup/imscp-reconfigure -d
EOF
}

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
