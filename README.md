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
- `mpkg`, a small package manager for `.tar.xz` packages with repositories, dependencies and upgrades
- `menthol-setup` for the first boot: passwords, hostname, timezone, keymap
- Optional packages built from recipes in `packages/` (nano, htop, tmux, rsync, tree, which, nftables) and security defaults (`hardening`)

## Requirements

- An x86_64 Linux host that passes `version-check.sh`
- `sudo` for mount, umount, losetup, chroot, chown and mkdir
- QEMU and OVMF to test the image
- The 98 source tarballs from the LFS 13.1 book in `sources/`, plus the BLFS tarballs used by `scripts/blfs*.sh`

## Building

`build.sh` runs the stages in order and writes one log per stage to `logs/`.

```
./build.sh mkimage         # new, empty, partitioned menthol.img (only for a fresh build)
./build.sh fetch           # download the LFS sources and check their md5sums
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
| `polish` | chroot | prompt, MOTD, `menthol-info`, `menthol-setup`, user `menthol` |
| `blfs`, `blfs-git` | chroot | curl, wget, sudo, OpenSSH, git |
| `mpkg-setup` | chroot | the `mpkg` package manager |
| `packages` | chroot | builds and installs the recipes in `packages/` |
| `hardening` | chroot | sysctl defaults, sshd settings, firewall |
| `desktop` | chroot | the desktop picked with `--desktop` (default: none) |

Host stages run as your user with a clean environment. Chroot stages are copied to
`/lfs-scripts` inside the image and run there as root.

`mkimage` creates a GPT image with an EFI partition (`MENTHOLEFI`), an ext4 root
(`MentholRoot`) and a bios_grub partition at sectors 34-2047. It never overwrites an existing
image. Not scripted: the BLFS tarballs for `blfs` and `blfs-git`, the `chown` to root before
`ch7` (`build.sh` tells you the command), and the first passwords.

The image and mount point default to `menthol.img` in the checkout and `/mnt/lfs`. Override
them with `MENTHOL_IMG` and `LFS`.

### Status of the newer scripts

`mkimage`, `ch7`, `mpkg-setup`, `packages`, `hardening` and `desktop` have not been run against an image yet. They pass a syntax
check and shellcheck, nothing more. `mpkg` itself has a test suite (`./build.sh test-mpkg`),
and `fetch` and `menthol-setup` were tried outside the image. `ch7` is a reconstruction from the book, because the script
that built the current image was never committed. It refuses to run on a system that already
has `/etc/passwd`.

### Hardening

`hardening` writes `/etc/sysctl.d/50-menthol.conf`, an sshd drop-in, and `/etc/nftables.conf`
(drop incoming traffic except SSH, ping and replies). The firewall is enabled only if `nft` is
installed and the installed kernel has nf_tables. `ch10-kernel` now turns that on, so an existing
image needs a kernel rebuild first. `SSH_KEY_ONLY=1 ./build.sh run hardening` also turns off
password logins over SSH.

## Packages (mpkg)

`mpkg` installs binary packages. A package is a `.tar.xz` with the files relative to `/` and a
`.MPKG/info` file (name, version, dependencies). It is a single bash script and needs only
tar, xz, curl and coreutils.

```
mpkg update              # download the package lists
mpkg search nano
mpkg install nano        # also installs dependencies
mpkg install ./foo-1.0-1-x86_64.tar.xz
mpkg upgrade             # refresh the lists and upgrade everything
mpkg remove nano
mpkg autoremove          # drop dependencies nothing needs any more
mpkg hold nano           # keep a package at its version during upgrades
mpkg list | info NAME | files NAME | owner PATH | verify | clean
```

It keeps changed files in `/etc` (the new version lands next to them as `.mpkgnew`), refuses
to overwrite files of other packages, and only removes directories it created itself.
`--root DIR` works on a system mounted somewhere else.

A dependency can carry a version, for example `libfoo>=1.2`. The LFS base system is not
registered as packages, so do not list base libraries such as glibc as dependencies.

Downloads are checked against the SHA-256 in the package list. The list itself is checked
against an OpenSSL signature when the repository's public key is in `/etc/mpkg/keys/`. Without
a key the list is only as trustworthy as HTTPS, and `mpkg update` says so.

### Building and publishing packages

Recipes live in `packages/`, see [packages/README.md](packages/README.md) for the format, the
state of each recipe and how to sign and upload. The default repository is the `packages`
release of this GitHub repository. Nothing has been published yet and no signing key exists
yet, so `mpkg update` finds no list until that release exists.

### Desktop

```
./build.sh --desktop xfce run desktop
```

The `desktop` stage records the choice in `/etc/menthol/desktop` and runs
`mpkg install desktop-<name>` for `xfce`, `kde` or `gnome`. Those are meta packages that pull in
the whole desktop. They do not exist yet, so today only `--desktop none` (the default) works.
An installer such as Calamares can offer the same choice later by running that one command.

## First boot

The image ships with temporary passwords. Log in and run:

```
sudo menthol-setup
```

It asks for new passwords, hostname, timezone and console keymap, and can create a user and
new SSH host keys. The login message points to it until it has run once. Installers can use
it without questions: `menthol-setup --root /mnt/target --non-interactive --hostname box`.

## Testing

```
cp /usr/share/OVMF/OVMF_VARS_4M.fd vars.fd
MENTHOL_TEST_PW=<password of menthol> ./build.sh test uefi vars.fd
MENTHOL_TEST_PW=<password of menthol> ./build.sh test bios
```

The test boots the image in QEMU, logs in over the serial console and checks the user, sudo,
HTTPS, git, sshd, mpkg and the systemd state. It exits non-zero if any check fails. See the top of
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
