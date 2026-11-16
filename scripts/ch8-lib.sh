set -e
export MAKEFLAGS=-j12 NINJAJOBS=12
mkdir -p /build; cd /build
S=/sources
unpack() { local d; d=$(tar -tf $S/$1 | head -1 | cut -d/ -f1); rm -rf $d; tar -xf $S/$1; cd $d; PKGDIR=$d; echo "=== $1"; }
done_pkg() { cd /build; rm -rf $PKGDIR; }
std() { ./configure --prefix=/usr "$@" && make && make install; }
pipinst() { pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD && pip3 install --no-index --find-links dist "$1"; }
