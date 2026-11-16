#!/bin/bash
# Run a script (path inside the image) in the chroot: chroot.sh /lfs-scripts/foo.sh [VAR=val ...]
. "$(dirname "$(readlink -f "$0")")/host-lib.sh"
[ $# -ge 1 ] || { echo "usage: chroot.sh /lfs-scripts/SCRIPT.sh [VAR=val ...]" >&2; exit 2; }
mountpoint -q "$LFS/proc" || { echo "$LFS is not mounted, run scripts/mount-image.sh first" >&2; exit 1; }
S=$1; shift
[ -f "$LFS$S" ] || { echo "no such script in the image: $S" >&2; exit 1; }
exec sudo -n /usr/bin/chroot "$LFS" /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/bin:/usr/sbin "$@" /bin/bash "$S"
