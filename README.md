TakeOff-ImageInstaller
=====================

## Notes
### Changing config file
by default we will use config.json, we can however change this by setting the environment variable TAKEOFF_CONFIG to a different value, then we will use this value with .json appended to it. For example: `export TAKEOFF_CONFIG='takeoff'` will use takeoff.json as config file.

### Removing the admin password asking:
#### OS X
    Cmnd_Alias VAGRANT_EXPORTS_ADD = /usr/bin/tee -a /etc/exports
    Cmnd_Alias VAGRANT_NFSD = /sbin/nfsd restart
    Cmnd_Alias VAGRANT_EXPORTS_REMOVE = /usr/bin/sed -E -e /*/ d -ibak /etc/exports
    %admin ALL=(root) NOPASSWD: VAGRANT_EXPORTS_ADD, VAGRANT_NFSD, VAGRANT_EXPORTS_REMOVE

#### Ubuntu Linux
    Cmnd_Alias VAGRANT_EXPORTS_ADD = /usr/bin/tee -a /etc/exports
    Cmnd_Alias VAGRANT_NFSD_CHECK = /etc/init.d/nfs-kernel-server status
    Cmnd_Alias VAGRANT_NFSD_START = /etc/init.d/nfs-kernel-server start
    Cmnd_Alias VAGRANT_NFSD_APPLY = /usr/sbin/exportfs -ar
    Cmnd_Alias VAGRANT_EXPORTS_REMOVE = /bin/sed -r -e * d -ibak /etc/exports
    %sudo ALL=(root) NOPASSWD: VAGRANT_EXPORTS_ADD, VAGRANT_NFSD_CHECK, VAGRANT_NFSD_START, VAGRANT_NFSD_APPLY, VAGRANT_EXPORTS_REMOVE

#### Fedora Linux
    Cmnd_Alias VAGRANT_EXPORTS_ADD = /usr/bin/tee -a /etc/exports
    Cmnd_Alias VAGRANT_NFSD_CHECK = /usr/bin/systemctl status nfs-server.service
    Cmnd_Alias VAGRANT_NFSD_START = /usr/bin/systemctl start nfs-server.service
    Cmnd_Alias VAGRANT_NFSD_APPLY = /usr/sbin/exportfs -ar
    Cmnd_Alias VAGRANT_EXPORTS_REMOVE = /bin/sed -r -e * d -ibak /etc/exports
    %vagrant ALL=(root) NOPASSWD: VAGRANT_EXPORTS_ADD, VAGRANT_NFSD_CHECK, VAGRANT_NFSD_START, VAGRANT_NFSD_APPLY, VAGRANT_EXPORTS_REMOVE

## Reference
https://docs.docker.com/reference/commandline/cli/#exec
