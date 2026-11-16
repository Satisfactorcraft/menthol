# MentholLinux

MentholLinux is a small Linux distribution built from source with
[Linux From Scratch](https://www.linuxfromscratch.org/) 13.1 (systemd). This repository holds
the build scripts and docs. The result is a 30 GB sparse raw disk image, `menthol.img`, that
boots under UEFI and legacy BIOS with GRUB.

Only scripts and docs are tracked. The image, the source tarballs (`sources/`), the book
extract (`book/`) and the build logs (`logs/`) live next to the checkout and are ignored by git.

## What you get

- LFS 13.1 base system with systemd, Linux 7.1.8 (defconfig + `kvm_guest.config`, no initramfs)
- GRUB for UEFI (removable path) and BIOS, with normal, recovery and verbose boot entries
- curl, wget, sudo, OpenSSH (root login off) and git from BLFS
- A branded prompt and MOTD, the user `menthol` in `wheel`, and `menthol-info` for a quick system summary
- Optional: nano, htop, tmux, rsync, tree, which, nftables (`blfs-extras`) and security defaults (`hardening`)

## Requirements

- An x86_64 Linux host that passes `version-check.sh`
- `sudo` for mount, umount, losetup, chroot, chown and mkdir
- QEMU and OVMF to test the image
- The 98 source tarballs from the LFS 13.1 book in `sources/`, plus the BLFS tarballs used by `scripts/blfs*.sh`

## Building

`build.sh` runs the stages in order and writes one log per stage to `logs/`.

```
./build.sh list            # stages in build order
./build.sh mount           # attach menthol.img at /mnt/lfs
./build.sh run ch8-a       # run one or more stages
./build.sh umount
```

| Stage | Runs | What it does |
| --- | --- | --- |
| `ch5-a`, `ch5-b` | host | cross-toolchain, kernel headers, glibc, libstdc++ |
| `ch6` | host | cross-compiled temporary tools |
| `ch7` | chroot | directory tree, `/etc/passwd`, extra temporary tools |
| `ch8-a`, `ch8-b`, `ch8-c` | chroot | the final system |
| `ch9` | chroot | network, locale, fstab, branding |
| `ch10-kernel` | chroot | kernel |
| `boot-extras` | chroot | GRUB for UEFI and BIOS, boot menu |
| `polish` | chroot | prompt, MOTD, `menthol-info`, user `menthol` |
| `blfs`, `blfs-git` | chroot | curl, wget, sudo, OpenSSH, git |
| `blfs-extras` | chroot | optional tools, see below |
| `hardening` | chroot | sysctl defaults, sshd settings, firewall |

Host stages run as your user with a clean environment. Chroot stages are copied to
`/lfs-scripts` inside the image and run there as root.

Not scripted: creating and partitioning the image (GPT with a bios_grub partition at sectors
34-2047, an EFI partition labelled `MENTHOLEFI` and an ext4 root labelled `MentholRoot`),
downloading the sources, and setting the passwords for `root` and `menthol`.

The image and mount point default to `menthol.img` in the checkout and `/mnt/lfs`. Override
them with `MENTHOL_IMG` and `LFS`.

### Status of the newer scripts

`ch7`, `blfs-extras` and `hardening` have not been run against an image yet. They pass a syntax
check and shellcheck, nothing more. `ch7` is a reconstruction from the book, because the script
that built the current image was never committed. It refuses to run on a system that already
has `/etc/passwd`.

### Optional packages

`blfs-extras` builds whatever it finds in `sources/` and skips the rest, so versions are not
pinned. `scripts/extras-sources.txt` lists where to get each tarball.

### Hardening

`hardening` writes `/etc/sysctl.d/50-menthol.conf`, an sshd drop-in, and `/etc/nftables.conf`
(drop incoming traffic except SSH, ping and replies). The firewall is enabled only if `nft` is
installed and the installed kernel has nf_tables. `ch10-kernel` now turns that on, so an existing
image needs a kernel rebuild first. `SSH_KEY_ONLY=1 ./build.sh run hardening` also turns off
password logins over SSH.

## Testing

```
cp /usr/share/OVMF/OVMF_VARS_4M.fd vars.fd
MENTHOL_TEST_PW=<password of menthol> ./build.sh test uefi vars.fd
MENTHOL_TEST_PW=<password of menthol> ./build.sh test bios
```

The test boots the image in QEMU, logs in over the serial console and checks the user, sudo,
HTTPS, git, sshd and the systemd state. It exits non-zero if any check fails. See the top of
`scripts/vmtest.py` for the settings, for example `MENTHOL_TEST_SNAPSHOT=1` to leave the image
untouched.

To boot it by hand:

```
qemu-system-x86_64 -enable-kvm -cpu host -m 2G -smp 4 -machine q35 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=vars.fd \
  -drive file=menthol.img,format=raw,if=virtio -nic user,model=virtio-net-pci
```

## Differences from the book

- All test suites are skipped, so Tcl, Expect and DejaGNU are not built
- Python is built without `--enable-optimizations`
- GRUB is built for i386-pc and x86_64-efi only
- groff uses A4 paper, the timezone is Europe/Berlin, the keymap is `de-latin1`
- sudo is built without PAM

## License

GPL-3.0, see [LICENSE](LICENSE).
