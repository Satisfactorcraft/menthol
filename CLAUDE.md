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

- Chapters 5, 6 and 7 are done.
- Chapter 8: part A (man-pages through GCC) in progress; B and C written, not yet run.
- Still to do: chapter 9 (config, os-release branding `MentholLinux`, fstab, network), chapter 10 (kernel linux-7.1.8, GRUB EFI, QEMU boot test).
- Open decision: root password for the image.
