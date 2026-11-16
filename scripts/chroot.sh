#!/bin/bash
# Run a script (path inside the image) in the chroot: chroot.sh /lfs-scripts/foo.sh [VAR=val ...]
S=$1; shift
exec sudo -n /usr/bin/chroot /mnt/lfs /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/bin:/usr/sbin "$@" /bin/bash "$S"
