#!/bin/bash
# Attach menthol.img and mount it, plus the virtual filesystems, at /mnt/lfs.
# Refuses to run if the image is already attached; undoes everything if a step fails.
set -eE
HERE=$(dirname "$(readlink -f "$0")")
IMG=${IMG:-$HERE/../menthol.img}
L=/mnt/lfs
if [ -n "$(losetup -j "$IMG" -O NAME -n)" ]; then
  echo "ERROR: $IMG is already attached ($(losetup -j "$IMG" -O NAME -n | head -1)); run scripts/umount-image.sh first" >&2
  exit 1
fi
cleanup() { echo "mount failed, undoing" >&2; "$HERE/umount-image.sh" || true; }
trap cleanup ERR
LOOP=$(sudo -n /usr/bin/losetup --find --show --partscan "$IMG")
udevadm settle
for p in p1 p2; do
  for _ in $(seq 50); do [ -b "$LOOP$p" ] && break; sleep 0.1; done
  [ -b "$LOOP$p" ]
done
sudo -n /usr/bin/mkdir -p $L $L/dev $L/proc $L/sys $L/run
sudo -n /usr/bin/mount "${LOOP}p2" $L
sudo -n /usr/bin/mkdir -p $L/boot/efi
sudo -n /usr/bin/mount "${LOOP}p1" $L/boot/efi
sudo -n /usr/bin/mount --bind /dev $L/dev
sudo -n /usr/bin/mount -t devpts devpts -o gid=5,mode=0620 $L/dev/pts
sudo -n /usr/bin/mount -t proc proc $L/proc
sudo -n /usr/bin/mount -t sysfs sysfs $L/sys
sudo -n /usr/bin/mount -t tmpfs tmpfs $L/run
sudo -n /usr/bin/mount -t tmpfs -o nosuid,nodev tmpfs $L/dev/shm
trap - ERR
echo "mounted $LOOP at $L"
