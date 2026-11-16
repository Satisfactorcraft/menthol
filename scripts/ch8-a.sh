. /lfs-scripts/ch8-lib.sh
unpack man-pages-6.18.tar.xz; rm -v man3/crypt*; make -R GIT=false prefix=/usr install; done_pkg
unpack iana-etc-20260805.tar.gz; cp -v services protocols /etc; done_pkg

unpack glibc-2.44.tar.xz
patch -Np1 -i $S/glibc-fhs-1.patch
patch -Np1 -i $S/glibc-2.44-upstream_fixes-1.patch
mkdir -v build; cd build
../configure --prefix=/usr --disable-werror --disable-nscd libc_cv_slibdir=/usr/lib --enable-stack-protector=strong --enable-kernel=5.10
make
touch /etc/ld.so.conf
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
make install
sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd
localedef -i C -f UTF-8 C.UTF-8
localedef -i de_DE -f ISO-8859-1 de_DE
localedef -i de_DE -f UTF-8 de_DE.UTF-8
localedef -i en_GB -f UTF-8 en_GB.UTF-8
localedef -i en_US -f ISO-8859-1 en_US
localedef -i en_US -f UTF-8 en_US.UTF-8
cat > /etc/nsswitch.conf << "EOT"
# Begin /etc/nsswitch.conf

passwd: files systemd
group: files systemd
shadow: files systemd

hosts: mymachines resolve [!UNAVAIL=return] files myhostname dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOT
tar -xf $S/tzdata2026c.tar.gz
ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}
for tz in etcetera southamerica northamerica europe africa antarctica asia australasia backward; do
    zic -L /dev/null   -d $ZONEINFO       ${tz}
    zic -L /dev/null   -d $ZONEINFO/posix ${tz}
    zic -L leapseconds -d $ZONEINFO/right ${tz}
done
cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p America/New_York
ln -sfv /usr/share/zoneinfo/Europe/Berlin /etc/localtime
cat > /etc/ld.so.conf << "EOT"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOT
mkdir -pv /etc/ld.so.conf.d
done_pkg

unpack zlib-1.3.2.tar.gz; std; rm -fv /usr/lib/libz.a; done_pkg

unpack bzip2-1.0.8.tar.gz
patch -Np1 -i $S/bzip2-1.0.8-install_docs-1.patch
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
make -f Makefile-libbz2_so; make clean
make; make PREFIX=/usr install
cp -av libbz2.so.* /usr/lib
ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so
ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so.1
cp -v bzip2-shared /usr/bin/bzip2
for i in /usr/bin/{bzcat,bunzip2}; do ln -sfv bzip2 $i; done
rm -fv /usr/lib/libbz2.a; done_pkg

unpack xz-5.8.3.tar.xz; std --disable-static --docdir=/usr/share/doc/xz-5.8.3; done_pkg
unpack lz4-1.10.0.tar.gz; make BUILD_STATIC=no PREFIX=/usr && make BUILD_STATIC=no PREFIX=/usr install; done_pkg
unpack zstd-1.5.7.tar.gz; make prefix=/usr && make prefix=/usr install && rm -v /usr/lib/libzstd.a; done_pkg
unpack file-5.48.tar.gz; std; done_pkg

unpack readline-8.3.tar.gz
sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install
sed -i 's/-Wl,-rpath,[^ ]*//' support/shobj-conf
sed -e '270a\
     else\
       chars_avail = 1;'      \
    -e '288i\   result = -1;' \
    -i.orig input.c
./configure --prefix=/usr --disable-static --with-curses --docdir=/usr/share/doc/readline-8.3
make SHLIB_LIBS="-lncursesw" && make install
install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.3; done_pkg

unpack pcre2-10.47.tar.bz2
std --docdir=/usr/share/doc/pcre2-10.47 --enable-unicode --enable-jit --enable-pcre2-16 --enable-pcre2-32 --enable-pcre2grep-libz --enable-pcre2grep-libbz2 --enable-pcre2test-libreadline --disable-static; done_pkg

unpack m4-1.4.21.tar.xz; std; done_pkg
unpack bc-7.0.3.tar.xz; CC='gcc -std=c99' ./configure --prefix=/usr -G -O3 -r && make && make install; done_pkg
unpack flex-2.6.4.tar.gz; std --disable-static --docdir=/usr/share/doc/flex-2.6.4; ln -sv flex /usr/bin/lex; ln -sv flex.1 /usr/share/man/man1/lex.1; done_pkg

unpack ninja-1.13.2.tar.gz
sed -i '/int Guess/a \
  int   j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;\
' src/ninja.cc
python3 configure.py --bootstrap --verbose
install -vm755 ninja /usr/bin/
install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja
done_pkg

unpack pkgconf-3.0.5.tar.xz
tar -xf $S/meson-1.12.0.tar.gz
mkdir build; cd build
python3 ../meson-1.12.0/meson.py setup --prefix=/usr --buildtype=release ..
ninja && ninja install
mv /usr/share/doc/pkgconf{,-3.0.5}
ln -sv pkgconf /usr/bin/pkg-config
ln -sv pkgconf.1 /usr/share/man/man1/pkg-config.1
done_pkg

unpack binutils-2.47.tar.xz
mkdir -v build; cd build
../configure --prefix=/usr --sysconfdir=/etc --enable-ld=default --enable-plugins --enable-shared --disable-werror --enable-64-bit-bfd --enable-new-dtags --with-system-zlib --with-lib-path=/usr/lib --enable-default-hash-style=gnu
make tooldir=/usr && make tooldir=/usr install
rm -rfv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a /usr/share/doc/gprofng/
done_pkg

unpack gmp-6.3.0.tar.xz
sed -i '/long long t1;/,+1s/()/(...)/' configure
./configure --prefix=/usr --enable-cxx --disable-static --docdir=/usr/share/doc/gmp-6.3.0
make && make html && make install && make install-html; done_pkg
unpack mpfr-4.2.2.tar.xz
./configure --prefix=/usr --disable-static --enable-thread-safe --docdir=/usr/share/doc/mpfr-4.2.2
make && make html && make install && make install-html; done_pkg
unpack mpc-1.4.1.tar.xz
./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/mpc-1.4.1
make && make html && make install && make install-html; done_pkg

unpack attr-2.6.0.tar.gz; std --disable-static --sysconfdir=/etc --docdir=/usr/share/doc/attr-2.6.0; done_pkg
unpack acl-2.4.0.tar.xz; std --disable-static --docdir=/usr/share/doc/acl-2.4.0; done_pkg
unpack libcap-2.78.tar.xz
sed -i '/install -m.*STA/d' libcap/Makefile
make prefix=/usr lib=lib && make prefix=/usr lib=lib install; done_pkg

unpack libxcrypt-4.5.2.tar.xz
sed -i '/strchr/s/const//' lib/crypt-{sm3,gost}-yescrypt.c
./configure --prefix=/usr --enable-hashes=strong,glibc --enable-obsolete-api=no --disable-static --disable-failure-tokens
make && make install
make distclean
./configure --prefix=/usr --enable-hashes=strong,glibc --enable-obsolete-api=glibc --disable-static --disable-failure-tokens
make
cp -av --remove-destination .libs/libcrypt.so.1* /usr/lib
done_pkg

unpack shadow-4.20.2.tar.xz
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;
sed -e 's:#ENCRYPT_METHOD SHA512:ENCRYPT_METHOD YESCRYPT:' -e 's:/var/spool/mail:/var/mail:' -e '/PATH=/{s@/sbin:@@;s@/bin:@@}' -i etc/login.defs
touch /usr/bin/passwd
./configure --sysconfdir=/etc --disable-static --with-{b,yes}crypt --without-libbsd --disable-logind --with-group-name-max-length=32
make && make exec_prefix=/usr install && make -C man install-man
pwconv; grpconv
mkdir -p /etc/default
useradd -D --gid 999
sed -i '/MAIL/s/yes/no/' /etc/default/useradd
touch /etc/sub{u,g}id
done_pkg

unpack gawk-5.4.1.tar.xz
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr && make
rm -f /usr/bin/gawk-5.4.1
make install
ln -sv gawk.1 /usr/share/man/man1/awk.1
install -vDm644 doc/{awkforai.txt,*.{eps,pdf,jpg}} -t /usr/share/doc/gawk-5.4.1
done_pkg

unpack gcc-16.2.0.tar.xz
case $(uname -m) in x86_64) sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64 ;; esac
mkdir -v build; cd build
../configure --prefix=/usr LD=ld --enable-languages=c,c++ --enable-default-pie --enable-default-ssp --enable-host-pie --enable-targets=all --disable-multilib --disable-bootstrap --disable-fixincludes --with-system-zlib
make && make install
chown -v -R root:root $(gcc -print-file-name=include){,-fixed}
ln -svr /usr/bin/cpp /usr/lib
ln -sv gcc.1 /usr/share/man/man1/cc.1
mkdir -pv /usr/lib/bfd-plugins
ln -sfvr $(gcc -print-prog-name=liblto_plugin.so) /usr/lib/bfd-plugins/
echo 'int main(){}' | cc -x c - -v -Wl,--verbose &> dummy.log
readelf -l a.out | grep ': /lib'
grep -E -o '/usr/lib.*/S?crt[1in].*succeeded' dummy.log
grep -B4 '^ /usr/include' dummy.log
grep "/lib.*/libc.so.6 " dummy.log
grep found dummy.log
rm -v a.out dummy.log
mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
done_pkg
echo "=== DONE ch8-a"
