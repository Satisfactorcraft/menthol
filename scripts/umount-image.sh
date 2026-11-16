#!/bin/bash
# Unmount /mnt/lfs and detach the loop device
L=/mnt/lfs
sync
for m in dev/shm dev/pts sys proc run dev boot/efi ""; do
  mountpoint -q "$L/$m" && sudo -n /usr/bin/umount "$L/$m"
done
for d in $(losetup -j /home/jan/LFS/menthol.img -O NAME -n); do sudo -n /usr/bin/losetup -d $d; done
echo "unmounted"; mount | grep -c /mnt/lfs || true
