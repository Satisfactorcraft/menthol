#!/bin/bash
# Unmount $LFS (/mnt/lfs) and detach the loop device
. "$(dirname "$(readlink -f "$0")")/host-lib.sh"
L=$LFS
sync
rc=0
for m in dev/shm dev/pts sys proc run dev boot/efi ""; do
  if mountpoint -q "$L/$m"; then sudo -n /usr/bin/umount "$L/$m" || rc=1; fi
done
for d in $(losetup -j "$MENTHOL_IMG" -O NAME -n); do sudo -n /usr/bin/losetup -d "$d" || rc=1; done
if [ $rc -eq 0 ]; then echo "unmounted"; else echo "some mounts are still busy:" >&2; mount | grep " $L" >&2; fi
exit $rc
