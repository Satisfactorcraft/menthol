#!/bin/bash
# Attach menthol.img and mount it with the virtual filesystems at $LFS (/mnt/lfs)
set -e
. "$(dirname "$(readlink -f "$0")")/host-lib.sh"
L=$LFS
[ -f "$MENTHOL_IMG" ] || { echo "image not found: $MENTHOL_IMG (set MENTHOL_IMG)" >&2; exit 1; }
if mountpoint -q "$L"; then echo "$L is already mounted"; exit 0; fi
LOOP=$(sudo -n /usr/bin/losetup --find --show --partscan "$MENTHOL_IMG")
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -b "${LOOP}p2" ] && break; sleep 0.5; done
sudo -n /usr/bin/mount "${LOOP}p2" "$L"
sudo -n /usr/bin/mount "${LOOP}p1" "$L/boot/efi"
sudo -n /usr/bin/mount --bind /dev "$L/dev"
sudo -n /usr/bin/mount -t devpts devpts -o gid=5,mode=0620 "$L/dev/pts"
sudo -n /usr/bin/mount -t proc proc "$L/proc"
sudo -n /usr/bin/mount -t sysfs sysfs "$L/sys"
sudo -n /usr/bin/mount -t tmpfs tmpfs "$L/run"
sudo -n /usr/bin/mount -t tmpfs -o nosuid,nodev tmpfs "$L/dev/shm"
echo "mounted $LOOP at $L"
