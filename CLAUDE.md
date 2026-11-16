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
- `scripts/ch7.sh`: chapter 7, reconstructed from the book and not yet run (refuses to run if `/etc/passwd` exists).
- `scripts/blfs-extras.sh`, `hardening.sh`: optional tools (unpinned versions, see `extras-sources.txt`) and security defaults. Not yet run against an image.
- `scripts/files/menthol-info`: system summary tool, installed by `polish.sh`.
- `scripts/host-lib.sh`: shared paths for host helpers (`MENTHOL_HOME`, `MENTHOL_IMG`, `LFS`); nothing hard-codes `/home/jan/LFS` any more.
- `scripts/files/mpkg`: package manager (bash). `.tar.xz` packages with `.MPKG/info`, repos in `/etc/mpkg/repos.conf` (default: the `packages` GitHub release), database in `/var/lib/mpkg`. Installed by `mpkg-setup.sh`. Tested only in a sandbox with `--root`, not in the image.
- `scripts/desktop.sh`: `DESKTOP=none|xfce|kde|gnome` runs `mpkg install desktop-<name>`; selected with `build.sh --desktop NAME`, meant to become a Calamares option. No desktop packages are published yet.
- `build.sh`: driver (`list`, `mount`, `umount`, `sync`, `run STAGE...`, `test`, `lint`), logs to `logs/<stage>.log`.
- `.github/workflows/lint.yml`: runs `./build.sh lint` (bash -n, py_compile, shellcheck at error level).
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
- Polish: branded prompt and MOTD (`/etc/profile.d/menthol.sh`), user `menthol` in `wheel` (temporary password), sudo.
- BLFS: curl 8.21.0, wget 1.25.0, sudo 1.9.17p2 (no PAM), OpenSSH 10.5p1 (root login off, sshd enabled), git 2.55.0 (built with NO_RUST=1). HTTPS uses a CA bundle copied from the build host.
- Boot: UEFI (removable path) and legacy BIOS (small bios_grub partition at sectors 34-2047); GRUB menu has normal, recovery (`rescue.target`) and verbose entries.
- Helpers: `scripts/mount-image.sh`, `umount-image.sh`, `chroot.sh`, and `scripts/vmtest.py MODE [VARS_FD]` (uefi|bios) for automated boot checks. It needs `MENTHOL_TEST_PW` and exits non-zero when a check fails.
- `ch10-kernel.sh` enables nf_tables for the firewall; the current image's kernel predates that and needs a rebuild before `hardening.sh` can enable nftables.
- Open: push `development` and open a PR (needs GitHub SSH host key verified and `gh` installed).

## QEMU test

```
qemu-system-x86_64 -enable-kvm -cpu host -m 2G -smp 4 -machine q35 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=vars.fd \
  -drive file=menthol.img,format=raw,if=virtio -nic user,model=virtio-net-pci
```

`vars.fd` is a copy of `/usr/share/OVMF/OVMF_VARS_4M.fd`.
