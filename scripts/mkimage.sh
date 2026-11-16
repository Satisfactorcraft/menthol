#!/bin/bash
# Create and partition a new, empty menthol.img and prepare it for chapter 5.
# NOT tested yet (needs parted, losetup and mkfs through sudo).
#   p1  EFI system partition, FAT32, label MENTHOLEFI (512 MiB)
#   p2  root, ext4, label MentholRoot (the rest)
#   p3  bios_grub, sectors 34-2047 (for GRUB on legacy BIOS)
# Size: MENTHOL_IMG_SIZE (default 30G, sparse). It never overwrites an existing image.
set -e
. "$(dirname "$(readlink -f "$0")")/host-lib.sh"
SIZE=${MENTHOL_IMG_SIZE:-30G}
[ -e "$MENTHOL_IMG" ] && { echo "$MENTHOL_IMG already exists, refusing to overwrite it" >&2; exit 1; }
mountpoint -q "$LFS" && { echo "$LFS is in use, unmount it first" >&2; exit 1; }
command -v parted > /dev/null || { echo "parted is not installed" >&2; exit 1; }

truncate -s "$SIZE" "$MENTHOL_IMG"
parted -s -a none "$MENTHOL_IMG" -- mklabel gpt \
  mkpart MENTHOLEFI fat32 2048s 1050623s set 1 esp on \
  mkpart MentholRoot ext4 1050624s -2048s \
  mkpart biosgrub 34s 2047s set 3 bios_grub on
parted -s "$MENTHOL_IMG" -- unit s print

LOOP=$(sudo -n /usr/bin/losetup --find --show --partscan "$MENTHOL_IMG")
trap 'mountpoint -q "$LFS" && sudo -n /usr/bin/umount "$LFS"; sudo -n /usr/bin/losetup -d "$LOOP"' EXIT
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -b "${LOOP}p2" ] && break; sleep 0.5; done
sudo -n /usr/bin/mkfs.fat -F 32 -n MENTHOLEFI "${LOOP}p1"
sudo -n /usr/bin/mkfs.ext4 -q -L MentholRoot "${LOOP}p2"

# Book chapter 4: the directory layout, owned by the build user until chapter 7
sudo -n /usr/bin/mkdir -p "$LFS"
sudo -n /usr/bin/mount "${LOOP}p2" "$LFS"
sudo -n /usr/bin/chown "$(id -un)" "$LFS"
mkdir -p "$LFS"/{etc,var,tools,build,sources,lfs-scripts,boot/efi,lib64} "$LFS"/usr/{bin,lib,sbin}
for d in bin lib sbin; do ln -s "usr/$d" "$LFS/$d"; done
chmod a+wt "$LFS/sources"
echo "created $MENTHOL_IMG ($SIZE). Next: scripts/fetch-sources.sh, then ./build.sh mount"
