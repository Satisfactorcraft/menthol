# Package recipes

One directory per package. `mpkg make` turns a recipe into a `.tar.xz` package.

```
mpkg make -o out packages/nano            # build
mpkg make -o out --install packages/nano  # build and install
```

Inside the image, `./build.sh run packages` builds everything in `order.txt`, installs it, and
leaves the packages plus `mpkg.index` in `/lfs-scripts/out`.

## Recipe format

A recipe is a bash file named `recipe`:

```
name=nano
version=9.3
release=1                       # optional, default 1; raise it to rebuild the same version
desc="Small, friendly text editor"
depends="libfoo bar>=1.2"       # optional; mpkg packages only, never LFS base libraries
options="nostrip"               # optional; binaries are stripped otherwise
source=(https://example.org/nano-$version.tar.xz)
sha256=(<checksum of each source, in the same order>)
build() {
  cd nano-$version
  ./configure --prefix=/usr
  make
  make DESTDIR="$PKG" install   # install into $PKG, never into /
}
```

- `build()` starts in a directory with the unpacked sources and stops at the first failing command.
- A source is taken from the recipe directory or `/sources` (`MPKG_SOURCES`) if it is there, otherwise downloaded.
- Files named `post-install` and `pre-remove` next to the recipe become the package's scripts.
- A recipe is code and runs as whoever calls `mpkg make`. Only build recipes you trust.

## Status

| Package | State |
| --- | --- |
| which, nano, tree, rsync | Version and checksum pinned. Built with `mpkg make` on an Ubuntu host (rsync there without zstd and lz4), not yet on MentholLinux. |
| htop, libevent, tmux, libmnl, libnftnl, nftables | UNVERIFIED. Version and URL are from memory and the checksum is `SKIP`, because their download hosts were not reachable when the recipes were written. Check the version, then pin the checksum with `sha256sum`. |

## Publishing

```
mpkg keygen ~/mpkg-key                          # once; keep mpkg.key private and out of git
cp ~/mpkg-key/mpkg.pub scripts/files/mpkg-menthol.pub   # commit this, mpkg-setup installs it
mpkg index --sign ~/mpkg-key/mpkg.key out       # writes mpkg.index and mpkg.index.sig
gh release upload packages out/* --clobber
```

Once a system has the public key in `/etc/mpkg/keys/menthol.pub`, it rejects a package list that
is unsigned or was changed after signing.
