#!/bin/bash
. /lfs-scripts/ch8-lib.sh
unpack linux-7.1.8.tar.xz
make mrproper
make defconfig
make kvm_guest.config
C=scripts/config
$C -d WERROR -d UEVENT_HELPER -d FW_LOADER_USER_HELPER -d LEGACY_TIOCSTI -d RT_GROUP_SCHED -d IKHEADERS -d PSI_DEFAULT_DISABLED
$C -e PSI -e CGROUPS -e MEMCG -e CGROUP_SCHED -e RELOCATABLE -e RANDOMIZE_BASE -e STACKPROTECTOR -e STACKPROTECTOR_STRONG
$C -e NET -e INET -e IPV6 -e DEVTMPFS -e DEVTMPFS_MOUNT -e DMIID -e SYSFB_SIMPLEFB -e TTY
$C -e EFI -e EFI_STUB -e EXT4_FS -e VFAT_FS -e FAT_FS -e TMPFS -e TMPFS_POSIX_ACL -e TMPFS_XATTR -e AUTOFS_FS
$C -e BLK_DEV_INITRD -e VIRTIO_BLK -e VIRTIO_PCI -e VIRTIO_NET -e SERIAL_8250 -e SERIAL_8250_CONSOLE
$C -e INOTIFY_USER -e FHANDLE -e EPOLL -e SIGNALFD -e TIMERFD -e EVENTFD -e SECCOMP -e SECCOMP_FILTER -e NAMESPACES
make olddefconfig
grep -E '^CONFIG_(DEVTMPFS_MOUNT|EXT4_FS|EFI_STUB|VIRTIO_BLK|CGROUPS|IPV6|PSI)=' .config
make
make modules_install
cp -v arch/x86/boot/bzImage /boot/vmlinuz-7.1.8-menthol
cp -v System.map /boot/System.map-7.1.8
cp -v .config /boot/config-7.1.8
install -d /usr/share/doc/linux-7.1.8
cp -r Documentation -T /usr/share/doc/linux-7.1.8
done_pkg
echo "=== DONE ch10-kernel"
