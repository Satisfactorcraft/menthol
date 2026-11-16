#!/bin/bash
# Host side. Copy the chroot scripts into the mounted image (/mnt/lfs/lfs-scripts).
set -e
HERE=$(dirname "$(readlink -f "$0")")
DEST=/mnt/lfs/lfs-scripts
[ -d "$DEST" ] || { echo "ERROR: $DEST missing; mount the image first" >&2; exit 1; }
cp -v "$HERE"/ch7.sh "$HERE"/ch8-lib.sh "$HERE"/ch8-[abc].sh "$HERE"/ch9.sh "$HERE"/ch10-kernel.sh \
     "$HERE"/boot-extras.sh "$HERE"/blfs.sh "$HERE"/polish.sh "$HERE"/harden.sh "$DEST"/
