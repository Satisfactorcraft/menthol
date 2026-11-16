set -e
JOBS=${JOBS:-$(nproc)}
export MAKEFLAGS=-j$JOBS NINJAJOBS=$JOBS
mkdir -p /build; cd /build
S=/sources
unpack() { local d; d=$(tar -tf $S/$1 | head -1 | cut -d/ -f1); rm -rf $d; tar -xf $S/$1; cd $d; PKGDIR=$d; echo "=== $1"; }
done_pkg() { cd /build; rm -rf $PKGDIR; }
std() { ./configure --prefix=/usr "$@" && make && make install; }
pipinst() { pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD && pip3 install --no-index --find-links dist "$1"; }
# find_src NAME -> newest $S/NAME-<version>.tar.* (empty if it was not downloaded)
find_src() { find $S -maxdepth 1 -name "$1-[0-9]*.tar.*" -printf '%f\n' | sort -V | tail -n 1; }
# unpack_any NAME -> like unpack, without pinning a version; returns 1 if the tarball is missing
unpack_any() { local t; t=$(find_src "$1"); if [ -z "$t" ]; then echo "--- skip $1 (no $1-*.tar.* in $S)"; return 1; fi; unpack "$t"; }
