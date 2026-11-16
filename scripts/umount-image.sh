#!/bin/bash
# Unmount everything under /mnt/lfs, then detach the loop device.
# If any unmount fails it stops with an error and does NOT detach the loop device.
HERE=$(dirname "$(readlink -f "$0")")
IMG=${IMG:-$HERE/../menthol.img}
L=/mnt/lfs
sync
fail=0
for m in dev/shm dev/pts sys proc run dev boot/efi ""; do
  if mountpoint -q "$L/$m"; then
    sudo -n /usr/bin/umount "$L/$m" || { echo "ERROR: cannot unmount $L/$m (busy? try: fuser -vm $L)" >&2; fail=1; }
  fi
done
if [ $fail -ne 0 ]; then
  echo "NOT detaching the loop device; free the busy mounts and run this script again" >&2
  exit 1
fi
for d in $(losetup -j "$IMG" -O NAME -n); do sudo -n /usr/bin/losetup -d "$d"; done
echo "unmounted and detached"
