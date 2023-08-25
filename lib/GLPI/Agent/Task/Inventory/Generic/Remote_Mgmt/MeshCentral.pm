package GLPI::Agent::Task::Inventory::Generic::Remote_Mgmt::MeshCentral;

use strict;
use warnings;

use parent 'GLPI::Agent::Task::Inventory::Module';

use English qw(-no_match_vars);

use GLPI::Agent::Tools;

sub _get_meshcentral_config {
    my @configs = ();
    if (OSNAME eq 'MSWin32') {
        push @configs, Glob('C:\Program Files\*\*\*.msh');
        if (has_folder('C:\Program Files (x86)')) {
            push @configs, Glob('C:\Program Files (x86)\*\*\*.msh');
        }
    } elsif (OSNAME eq 'darwin') {
        push @configs, Glob('/usr/local/mesh_services/*/*.msh');
    } else {
        push @configs, Glob('/usr/local/mesh_services/*/*/*.msh');
    }
    return grep { canRead($_) } @configs;
}

sub isEnabled {
    return _get_meshcentral_config() ? 1 : 0;
}

sub doInventory {
    my (%params) = @_;

    my $inventory = $params{inventory};
    my $logger    = $params{logger};

    foreach my $conf (_get_meshcentral_config()) {
        my $meshServiceName = getFirstMatch(
            file    => $conf,
            logger  => $logger,
            pattern => qr/^meshServiceName=(\S+)/
        );

        if (defined($meshServiceName)) {
            my $nodeId    = _getNodeId(logger => $logger, service => $meshServiceName)
                or next;
            my $serverUrl = getFirstMatch(
                file    => $conf,
                logger  => $logger,
                pattern => qr/^MeshServer=wss:\/\/(\S+):\d+\/agent.ashx/
            );
        }

        if (defined($serverUrl) && defined($nodeId)) {
            $logger->debug('Found MeshCentral nodeId : ' . $nodeId .' at ' . $serverUrl) if $logger;

            $inventory->addEntry(
                section => 'REMOTE_MGMT',
                entry   => {
                    ID   => $nodeId,
                    TYPE => 'meshcentral',
                    URL  => $serverUrl
                }
            );
        } else {
            $logger->debug('MeshCentral nodeId not found for '.$conf) if $logger;
        }
    }
}

sub _getNodeId {
    my (%params) = @_;

    return _winBased(%params) if OSNAME eq 'MSWin32';
    return _darwinBased(%params) if OSNAME eq 'darwin';
    return _linuxBased(%params);
}

sub _winBased {
    my (%params) = @_;

    my $nodeId = getRegistryValue(
        path        => "HKEY_LOCAL_MACHINE/SOFTWARE/Open Source/".$params{service}."/NodeId",
        logger      => $params{logger}
    );

    return $nodeId;
}

sub _linuxBased {
    my (%params) = @_;

    my $command = getFirstLine(
        file    => "/etc/systemd/system/".$params{service}.".service",
        pattern => qr/Ex.*=(.*)\s\-/,
        logger  => $params{logger},
    );

    return getFirstLine(
        command => "${command} -nodeid",
        logger  => $params{logger}
    );
}

sub _darwinBased {
    my (%params) = @_;
    return getFirstLine(
        command => "/usr/local/mesh_services/meshagent/meshagent_osx64 -nodeid",
        logger  => $params{logger}
    );
}

1;
