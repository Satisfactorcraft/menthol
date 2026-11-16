# MentholLinux (LFS 13.1, systemd)

MentholLinux is a Linux From Scratch build following the LFS 13.1 systemd book. The target is a 30 GB sparse raw image (`menthol.img`), tested under QEMU with OVMF (UEFI) and GRUB. Hostname: `menthol`.

## Git rules (strict)

- NEVER push to `main`. All work goes on `development` (or a feature branch) and reaches `main`/`testing` only through a pull request.
- Do NOT add `Co-Authored-By` lines or any Claude attribution to commits or PR descriptions.
- Author identity is set per repo: Satisfactorcraft. Do not change it and do not use any other email.
- Remote: `git@github.com:Satisfactorcraft/menthol.git`. Ask before pushing anything new.
- Track only scripts and docs. `.gitignore` excludes `menthol.img`, `sources/`, `book/`, `logs/`.

## Layout

- `lfs-env.sh`: build environment for chapters 5 and 6 (`LFS=/mnt/lfs`, `LFS_TGT`, clean `PATH`).
- `version-check.sh`: host requirements check from the book.
- `scripts/ch5-a.sh`, `ch5-b.sh`: cross-toolchain, headers, glibc, libstdc++.
- `scripts/ch6.sh`: cross-compiled temporary tools.
- `scripts/ch8-lib.sh`, `ch8-a.sh`, `ch8-b.sh`, `ch8-c.sh`: final system, run inside the chroot.
- Outside the repo: `menthol.img`, `sources/` (98 tarballs, md5-verified), `book/` (LFS 13.1 extract), `logs/`.

## Build workflow

- The image is loop-mounted at `/mnt/lfs`: root on `loop0p2`, EFI on `loop0p1` at `/mnt/lfs/boot/efi`.
- Chapters 5 and 6 run as `jan` with `env -i`, with no separate `lfs` user.
- From chapter 7 on, scripts run in the chroot: `sudo chroot /mnt/lfs /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/bin:/usr/sbin /bin/bash /lfs-scripts/<script>`.
- `/mnt/lfs` is owned by root, so scripts for the chroot are written to `scripts/` and copied into `/mnt/lfs/lfs-scripts/` (owned by `jan`).
- Passwordless sudo is limited to `/etc/sudoers.d/lfs-build` (mount, umount, losetup, chroot, mkfs, parted, chown, chmod, mkdir, env, pacman). Remove it when the build is finished.

## Deliberate deviations from the book

- All test suites are skipped.
- Tcl, Expect and DejaGNU are skipped (they only exist to run tests).
- Python is built without `--enable-optimizations`.
- GRUB is built for i386-pc and x86_64-efi only, no i386-efi.
- groff uses A4 paper, and the timezone is Europe/Berlin.
- `lfs-bootscripts` is not used (SysVinit only, 404 on the mirror).

## Status

- All chapters are done. `menthol.img` boots in QEMU (OVMF + GRUB EFI) to `menthol login:` with 101 units OK and none failed.
- Scripts: `ch9.sh` (config and branding), `ch10-kernel.sh` (Linux 7.1.8 from defconfig + kvm_guest.config), `ch10-grub.sh` (needs `ROOT_PARTUUID`).
- Kernel: no initramfs, root found via `root=PARTUUID=...`, console on tty0 and ttyS0.
- The chapter 7 chroot script was written inside the image and is not in this repo.
- Root password is a temporary one set at build time. Change it with `passwd` after the first login.
- Open: push `development` and open a PR (needs GitHub SSH host key verified and `gh` installed).

## QEMU test

```
qemu-system-x86_64 -enable-kvm -cpu host -m 2G -smp 4 -machine q35 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=vars.fd \
  -drive file=menthol.img,format=raw,if=virtio -nic user,model=virtio-net-pci
```

`vars.fd` is a copy of `/usr/share/OVMF/OVMF_VARS_4M.fd`.
