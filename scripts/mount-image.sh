#!/bin/bash
# Attach menthol.img and mount it with the virtual filesystems at /mnt/lfs
set -e
IMG=/home/jan/LFS/menthol.img; L=/mnt/lfs
LOOP=$(sudo -n /usr/bin/losetup --find --show --partscan $IMG); sleep 1
sudo -n /usr/bin/mount ${LOOP}p2 $L
sudo -n /usr/bin/mount ${LOOP}p1 $L/boot/efi
sudo -n /usr/bin/mount --bind /dev $L/dev
sudo -n /usr/bin/mount -t devpts devpts -o gid=5,mode=0620 $L/dev/pts
sudo -n /usr/bin/mount -t proc proc $L/proc
sudo -n /usr/bin/mount -t sysfs sysfs $L/sys
sudo -n /usr/bin/mount -t tmpfs tmpfs $L/run
sudo -n /usr/bin/mount -t tmpfs -o nosuid,nodev tmpfs $L/dev/shm
echo "mounted $LOOP at $L"
