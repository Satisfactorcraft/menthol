#!/bin/bash
# Host side, run once after ch6.sh and before mount-image.sh / ch7.sh:
# hand the tree to root (LFS 7.2), create the mount points and the jan-owned script directory.
set -e
L=/mnt/lfs
sudo -n /usr/bin/chown --from jan -R root:root $L/usr $L/var $L/etc $L/tools $L/lib64
sudo -n /usr/bin/chown -h --from jan root:root $L/bin $L/lib $L/sbin
sudo -n /usr/bin/mkdir -pv $L/dev $L/proc $L/sys $L/run $L/lfs-scripts
sudo -n /usr/bin/chown jan:jan $L/lfs-scripts
sudo -n /usr/bin/chown root:root $L
echo "=== DONE ch7-host"
