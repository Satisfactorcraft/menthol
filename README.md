# MentholLinux

MentholLinux is a [Linux From Scratch](https://www.linuxfromscratch.org/lfs/) 13.1 (systemd) build, plus a few BLFS packages, built from the scripts in this repository into a loop-mounted 30 GB disk image. It boots under QEMU with UEFI (OVMF) and legacy BIOS.

- Kernel 7.1.8, glibc 2.44, GCC 16.2, systemd 261.2, GRUB 2.14
- BLFS extras: curl, wget, sudo, OpenSSH (key-only), git
- Hostname `menthol`, branded `/etc/os-release`, prompt and MOTD

The image, the source tarballs and the logs are not part of the repository.

## Build

The scripts live in `scripts/`. Read `CLAUDE.md` for the build order, the helper scripts and the deliberate deviations from the book (for example: no test suites). In short: chapters 5 and 6 run on the host, chapters 7 to 10 and BLFS run in a chroot of the mounted image, and `scripts/vmtest.py` boots the finished image and checks it.

## Test

```
MENTHOL_TEST_PW=<password of user menthol> scripts/vmtest.py uefi
MENTHOL_TEST_PW=<password of user menthol> scripts/vmtest.py bios
```

Both exit with status 0 only if every check passes.

## Security

sshd only accepts keys and root login is disabled. The accounts have temporary passwords set at build time: change them at the first login, or set your own with `scripts/set-passwords.sh`.

## License

See `LICENSE`.
