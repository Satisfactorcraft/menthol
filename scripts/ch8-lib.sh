# Shared helpers for the chroot build scripts. Source it, do not run it:
#   . /lfs-scripts/ch8-lib.sh
set -eE
trap 'echo "FAILED: line $LINENO: $BASH_COMMAND" >&2' ERR
export MAKEFLAGS=-j$(nproc) NINJAJOBS=$(nproc)
mkdir -p /build
cd /build
S=/sources

# unpack TARBALL: extract into /build and cd into the source directory
unpack() {
  local d
  d=$(tar -tf $S/$1 | head -1 | cut -d/ -f1)
  rm -rf $d
  tar -xf $S/$1
  cd $d
  PKGDIR=$d
  echo "=== $1"
}
# done_pkg: leave and delete the source directory
done_pkg() {
  cd /build
  rm -rf $PKGDIR
}
# std [configure args]: configure, build and install into /usr
std() {
  echo "--- build $PKGDIR"
  ./configure --prefix=/usr "$@"
  make
  make install
}
# pipinst NAME: build a wheel from the current directory and install it
pipinst() {
  pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
  pip3 install --no-index --find-links dist "$1"
}
# add_line LINE FILE: append LINE to FILE only if it is not already there (re-run safe)
add_line() {
  grep -qxF -- "$1" "$2" 2>/dev/null || echo "$1" >> "$2"
}
