#!/bin/bash
. /lfs-scripts/ch8-lib.sh
unpack ncurses-6.6.tar.gz
./configure --prefix=/usr --mandir=/usr/share/man --with-shared --without-debug --without-normal --with-cxx-shared --enable-pc-files --with-pkg-config-libdir=/usr/lib/pkgconfig
make
make DESTDIR=$PWD/dest install
sed -e 's/^#if.*XOPEN.*$/#if 1/' -i dest/usr/include/curses.h
cp --remove-destination -av dest/* /
for lib in ncurses form panel menu ; do
    ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc    /usr/lib/pkgconfig/${lib}.pc
done
ln -sfv libncursesw.so /usr/lib/libcurses.so
cp -v -R doc -T /usr/share/doc/ncurses-6.6
make distclean
./configure --prefix=/usr --with-shared --without-normal --without-debug --without-cxx-binding --with-abi-version=5
make sources libs
cp -av lib/lib*.so.5* /usr/lib
done_pkg

unpack sed-4.10.tar.xz
./configure --prefix=/usr
make
make html
make install
install -vDm644 doc/sed.html -t /usr/share/doc/sed-4.10
done_pkg
unpack psmisc-23.7.tar.xz; std; done_pkg
unpack gettext-1.0.tar.xz; std --disable-static --docdir=/usr/share/doc/gettext-1.0; chmod -v 0755 /usr/lib/preloadable_libintl.so; done_pkg
unpack bison-3.8.2.tar.xz; std --docdir=/usr/share/doc/bison-3.8.2; done_pkg
unpack grep-3.12.tar.xz; sed -i "s/echo/#echo/" src/egrep.sh; std; done_pkg
unpack bash-5.3.tar.gz; std --without-bash-malloc --with-installed-readline --docdir=/usr/share/doc/bash-5.3; done_pkg
unpack libtool-2.6.2.tar.xz; std; rm -fv /usr/lib/libltdl.a; done_pkg
unpack gdbm-1.26.tar.gz; std --disable-static --enable-libgdbm-compat; done_pkg
unpack gperf-3.3.tar.gz; std --docdir=/usr/share/doc/gperf-3.3; done_pkg
unpack expat-2.8.3.tar.xz; std --disable-static --docdir=/usr/share/doc/expat-2.8.3; install -v -m644 doc/*.{html,css} /usr/share/doc/expat-2.8.3; done_pkg

unpack inetutils-2.8.tar.gz
sed -i 's/def HAVE_TERMCAP_TGETENT/ 1/' telnet/telnet.c
std --bindir=/usr/bin --localstatedir=/var --disable-logger --disable-whois --disable-rcp --disable-rexec --disable-rlogin --disable-rsh --disable-servers
if [ -e /usr/bin/ifconfig ]; then mv -v /usr/{,s}bin/ifconfig; fi
done_pkg

unpack less-704.tar.gz; std --sysconfdir=/etc; done_pkg

unpack perl-5.44.0.tar.xz
export BUILD_ZLIB=False BUILD_BZIP2=0
sh Configure -des -D prefix=/usr -D vendorprefix=/usr -D privlib=/usr/lib/perl5/5.44/core_perl -D archlib=/usr/lib/perl5/5.44/core_perl -D sitelib=/usr/lib/perl5/5.44/site_perl -D sitearch=/usr/lib/perl5/5.44/site_perl -D vendorlib=/usr/lib/perl5/5.44/vendor_perl -D vendorarch=/usr/lib/perl5/5.44/vendor_perl -D man1dir=/usr/share/man/man1 -D man3dir=/usr/share/man/man3 -D pager="/usr/bin/less -isR" -D useshrplib -D usethreads
make
make install
unset BUILD_ZLIB BUILD_BZIP2
done_pkg

unpack autoconf-2.73.tar.xz; std; done_pkg
unpack automake-1.18.1.tar.xz; std --docdir=/usr/share/doc/automake-1.18.1; done_pkg

unpack openssl-4.0.1.tar.gz
./config --prefix=/usr --openssldir=/etc/ssl --libdir=lib shared zlib-dynamic
make
make INSTALL_LIBS= MANSUFFIX=ssl install
mv -v /usr/share/doc/openssl /usr/share/doc/openssl-4.0.1
cp -vfr doc/* /usr/share/doc/openssl-4.0.1
done_pkg

unpack elfutils-0.195.tar.bz2
./configure --prefix=/usr --disable-debuginfod --enable-libdebuginfod=dummy
make -C lib
make -C libelf
make -C libelf install
install -vm644 config/libelf.pc /usr/lib/pkgconfig
rm /usr/lib/libelf.a
done_pkg

unpack libffi-3.8.0.tar.gz; std --disable-static --with-gcc-arch=native; done_pkg

unpack sqlite-autoconf-3530400.tar.gz
python3 -m zipfile -e $S/sqlite-doc-3530400.zip .
./configure --prefix=/usr --disable-static --enable-fts{4,5} CPPFLAGS="-D SQLITE_ENABLE_COLUMN_METADATA=1 -D SQLITE_ENABLE_UNLOCK_NOTIFY=1 -D SQLITE_ENABLE_DBSTAT_VTAB=1 -D SQLITE_SECURE_DELETE=1"
make LDFLAGS.rpath=""
make install
cp -v -R sqlite-doc-3530400 -T /usr/share/doc/sqlite-3.53.4
done_pkg

unpack mpdecimal-4.0.1.tar.gz; std --disable-static --docdir=/usr/share/doc/mpdecimal-4.0.1; done_pkg

unpack Python-3.14.7.tar.xz
patch -Np1 -i $S/Python-3.14.7-openssl_4-1.patch
./configure --prefix=/usr --enable-shared --with-system-expat --without-static-libpython
make
make install
cat > /etc/pip.conf << EOT
[global]
root-user-action = ignore
disable-pip-version-check = true
EOT
install -v -dm755 /usr/share/doc/python-3.14.7/html
tar --strip-components=1 --no-same-owner --no-same-permissions -C /usr/share/doc/python-3.14.7/html -xvf $S/python-3.14.7-docs-html.tar.bz2
done_pkg

unpack flit_core-4.0.2.tar.gz; pipinst flit_core; done_pkg
unpack packaging-26.3.tar.gz; pipinst packaging; done_pkg
unpack wheel-0.48.0.tar.gz; pipinst wheel; done_pkg
unpack setuptools-84.0.0.tar.gz; pipinst setuptools; done_pkg
unpack meson-1.12.0.tar.gz; pipinst meson
install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson
done_pkg

unpack kmod-34.2.tar.xz
mkdir -p build; cd build
meson setup --prefix=/usr .. --buildtype=release -D manpages=false
ninja
ninja install
done_pkg
echo "=== DONE ch8-b"
