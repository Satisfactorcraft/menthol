# Optional everyday tools (BLFS). NOT built or tested yet.
# Versions are not pinned: every package is built from the newest matching tarball in /sources
# and skipped when it is missing. See scripts/extras-sources.txt for where to download them.
. /lfs-scripts/ch8-lib.sh
built=""; skipped=""
note() { if [ "$2" = ok ]; then built="$built $1"; else skipped="$skipped $1"; fi; }

if unpack_any which; then
  std
  done_pkg; note which ok
else note which skip; fi

if unpack_any nano; then
  std --sysconfdir=/etc --enable-utf8 --docdir=/usr/share/doc/nano
  cat > /etc/nanorc << "EOT"
set autoindent
set constantshow
set linenumbers
set tabsize 4
include "/usr/share/nano/*.nanorc"
EOT
  done_pkg; note nano ok
else note nano skip; fi

if unpack_any htop; then
  [ -x configure ] || ./autogen.sh
  std
  done_pkg; note htop ok
else note htop skip; fi

if unpack_any tree; then
  make
  make PREFIX=/usr MANDIR=/usr/share/man install
  done_pkg; note tree ok
else note tree skip; fi

if unpack_any rsync; then
  std --disable-xxhash --without-included-zlib
  done_pkg; note rsync ok
else note rsync skip; fi

# tmux needs libevent
if unpack_any libevent; then
  sed -i 's/python/&3/' event_rpcgen.py
  std --disable-static
  done_pkg; note libevent ok
else note libevent skip; fi

if [ -e /usr/lib/libevent.so ] && unpack_any tmux; then
  std
  done_pkg; note tmux ok
else note tmux skip; fi

# nftables (firewall, configured by hardening.sh) needs libmnl and libnftnl
if unpack_any libmnl; then
  std --disable-static
  done_pkg; note libmnl ok
else note libmnl skip; fi

if [ -e /usr/lib/libmnl.so ] && unpack_any libnftnl; then
  std --disable-static
  done_pkg; note libnftnl ok
else note libnftnl skip; fi

if [ -e /usr/lib/libnftnl.so ] && unpack_any nftables; then
  ./configure --prefix=/usr --sbindir=/usr/sbin --sysconfdir=/etc --with-cli=readline --without-json --disable-man-doc
  make && make install
  done_pkg; note nftables ok
else note nftables skip; fi

echo "=== built:  ${built:- none}"
echo "=== skipped:${skipped:- none}"
echo "=== DONE blfs-extras"
