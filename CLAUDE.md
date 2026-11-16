# MentholLinux (LFS 13.1, systemd)

MentholLinux is a Linux From Scratch build following the LFS 13.1 systemd book. The target is a 30 GB sparse raw image (`menthol.img`), tested under QEMU with OVMF (UEFI) and with legacy BIOS, booted by GRUB. Hostname: `menthol`.

## Git rules (strict)

- NEVER push to `main`. All work goes on `development` (or a feature/bugfix branch) and reaches `main`/`testing` only through a pull request. Never merge a PR yourself.
- Do NOT add `Co-Authored-By` lines or any Claude attribution to commits, PR descriptions or issues.
- Author identity is set per repo: Satisfactorcraft. Do not change it and do not use any other email.
- Remote: `git@github.com:Satisfactorcraft/menthol.git`. Ask before pushing anything new. PRs are created with the GitHub MCP tools (no `gh` on this machine).
- Track only scripts and docs. `.gitignore` excludes `menthol.img`, `sources/`, `book/`, `logs/`.
- Never put passwords or tokens in the repo, in issues or in PRs.

## Layout

- `lfs-env.sh`: build environment for chapters 5 and 6 (`LFS=/mnt/lfs`, `LFS_TGT`, clean `PATH`).
- `version-check.sh`: host requirements check from the book.
- Host scripts (run as `jan`): `ch5-a.sh`, `ch5-b.sh` (cross-toolchain, headers, glibc, libstdc++), `ch6.sh` (temporary tools), `ch7-host.sh` (chown, mount points), `mount-image.sh`, `umount-image.sh`, `chroot.sh`, `install-scripts.sh`, `prepare-ca.sh`, `set-passwords.sh`, `vmtest.py`.
- Chroot scripts (run through `chroot.sh`): `ch7.sh`, `ch8-a.sh`, `ch8-b.sh`, `ch8-c.sh` (final system), `ch9.sh` (configuration, branding), `ch10-kernel.sh`, `boot-extras.sh` (GRUB for UEFI and BIOS), `blfs.sh` (curl, wget, sudo, OpenSSH, git), `polish.sh` (prompt, MOTD, user), `harden.sh` (sshd key-only, removes `tester`).
- `ch8-lib.sh` is sourced by the chroot scripts: helpers `unpack`, `done_pkg`, `std`, `pipinst`, `add_line`, plus an ERR trap that prints the failing line.
- Outside the repo: `menthol.img`, `sources/` (md5-verified tarballs), `book/` (LFS 13.1 extract), `logs/`.

## Build workflow

1. `scripts/ch5-a.sh`, `ch5-b.sh`, `ch6.sh` on the host (image mounted with `mount-image.sh`, `/mnt/lfs` owned by `jan`).
2. `scripts/ch7-host.sh`, then `scripts/install-scripts.sh`.
3. Chroot scripts in order: `scripts/chroot.sh /lfs-scripts/ch7.sh`, then `ch8-a.sh`, `ch8-b.sh`, `ch8-c.sh`, `ch9.sh`, `ch10-kernel.sh`, `polish.sh`, then `scripts/prepare-ca.sh` on the host and `blfs.sh`, `harden.sh`.
4. GRUB: `scripts/chroot.sh /lfs-scripts/boot-extras.sh ROOT_PARTUUID=<partuuid of the root partition> LOOPDEV=/dev/loopN`.
5. Set passwords on the host: `MENTHOL_ROOT_PW=... MENTHOL_USER_PW=... scripts/set-passwords.sh` (forces a change at first login; `--no-expire` for test images).
6. `scripts/umount-image.sh`, then `MENTHOL_TEST_PW=<password of menthol> scripts/vmtest.py uefi` and `... bios`.

Notes:
- The image is loop-mounted at `/mnt/lfs`: root on `loopNp2`, EFI on `loopNp1` at `/mnt/lfs/boot/efi`. The image also has a small `bios_grub` partition (sectors 34-2047) for legacy BIOS.
- Chapters 5 and 6 run as `jan` with `env -i`, with no separate `lfs` user.
- `/mnt/lfs` is root-owned from chapter 7 on, so chroot scripts are copied into `/mnt/lfs/lfs-scripts/` (owned by `jan`) with `install-scripts.sh`.
- The build scripts are written so that a failing command stops the script (no `make && make install` chains). Most are safe to re-run; `ch5`/`ch6`/`ch8` rebuild packages from scratch.
- Passwordless sudo is limited to `/etc/sudoers.d/lfs-build` (mount, umount, losetup, chroot, mkfs, parted, chown, chmod, mkdir, env, pacman). Remove it when the build is finished.

## Deliberate deviations from the book

- All test suites are skipped.
- Tcl, Expect and DejaGNU are skipped (they only exist to run tests), and no `tester` user is created.
- Python is built without `--enable-optimizations`.
- GRUB is built for i386-pc and x86_64-efi only, no i386-efi.
- groff uses A4 paper, and the timezone is Europe/Berlin.
- `lfs-bootscripts` is not used (SysVinit only).
- sudo and OpenSSH are built without PAM; git is built with `NO_RUST=1`; curl and wget are built without libpsl.
- HTTPS trust uses the CA bundle of the build host (`prepare-ca.sh`) instead of `make-ca`.

## Status

- All chapters are done. `menthol.img` passes `vmtest.py` on UEFI and on BIOS (16 checks each).
- Kernel: Linux 7.1.8 from defconfig + kvm_guest.config, no initramfs, root found via `root=PARTUUID=...`. The kernel command line ends with `console=tty0`, so `/dev/console` is the screen; the serial port also gets output and a login.
- sshd is enabled but key-only, root login is off. Both accounts (`root`, `menthol`) have temporary passwords set at build time: change them at first login (or use `set-passwords.sh`).
- GRUB menu: normal, recovery (`rescue.target`) and verbose entries.
- Bug-hunt issues #2-#14 are fixed on branch `bugfix/bug-hunt-issues` (PR pending review).

## QEMU test by hand

```
qemu-system-x86_64 -enable-kvm -cpu host -m 2G -smp 4 -machine q35 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=vars.fd \
  -drive file=menthol.img,format=raw,if=virtio -nic user,model=virtio-net-pci
```

`vars.fd` is a copy of `/usr/share/OVMF/OVMF_VARS_4M.fd`. For legacy BIOS drop the `-machine` and `pflash` lines.
