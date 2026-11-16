#!/bin/bash
set -e
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lfs-env.sh"
cd $LFS/build
S=$LFS/sources
# unpack TARBALL -> enters source dir
unpack() { local d; d=$(tar -tf $S/$1 | head -1 | cut -d/ -f1); rm -rf $d; tar -xf $S/$1; cd $d; PKGDIR=$d; }
done_pkg() { cd $LFS/build; rm -rf $PKGDIR; }
std() { ./configure --prefix=/usr --host=$LFS_TGT --build=$(./build-aux/config.guess) "$@" && make && make DESTDIR=$LFS install; }

echo "=== m4"; unpack m4-1.4.21.tar.xz
cat > $LFS/usr/share/config.site << EOT
ac_cv_func_posix_spawn_file_actions_addchdir=yes
ac_cv_func_posix_spawn_file_actions_addfchdir=yes
EOT
std; done_pkg

echo "=== ncurses"; unpack ncurses-6.6.tar.gz
mkdir build; pushd build; ../configure --prefix=$LFS/tools AWK=gawk; make -C include; make -C progs tic; install progs/tic $LFS/tools/bin; popd
./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess) --mandir=/usr/share/man --with-manpage-format=normal --with-shared --without-normal --with-cxx-shared --without-debug --without-ada --disable-stripping AWK=gawk
make && make DESTDIR=$LFS install
ln -sv libncursesw.so $LFS/usr/lib/libncurses.so
sed -e 's/^#if.*XOPEN.*$/#if 1/' -i $LFS/usr/include/curses.h
done_pkg

echo "=== bash"; unpack bash-5.3.tar.gz
./configure --prefix=/usr --build=$(sh support/config.guess) --host=$LFS_TGT --without-bash-malloc --docdir=/usr/share/doc/bash-5.3
make && make DESTDIR=$LFS install
ln -sfv bash $LFS/bin/sh
done_pkg

echo "=== coreutils"; unpack coreutils-9.11.tar.xz
./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) --enable-install-program=hostname
make && make DESTDIR=$LFS install
mv -v $LFS/usr/bin/chroot $LFS/usr/sbin
mkdir -pv $LFS/usr/share/man/man8
mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' $LFS/usr/share/man/man8/chroot.8
done_pkg

echo "=== diffutils"; unpack diffutils-3.12.tar.xz
std gl_cv_func_strcasecmp_works=yes; done_pkg

echo "=== file"; unpack file-5.48.tar.gz
mkdir build; pushd build; ../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib; make; popd
./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
make FILE_COMPILE=$(pwd)/build/src/file && make DESTDIR=$LFS install
rm -v $LFS/usr/lib/libmagic.la
done_pkg

echo "=== findutils"; unpack findutils-4.11.0.tar.xz
std --localstatedir=/var/lib/locate; done_pkg

echo "=== gawk"; unpack gawk-5.4.1.tar.xz
sed -i 's/extras//' Makefile.in
std; done_pkg

echo "=== grep"; unpack grep-3.12.tar.xz; std; done_pkg

echo "=== gzip"; unpack gzip-1.14.tar.xz
./configure --prefix=/usr --host=$LFS_TGT && make && make DESTDIR=$LFS install; done_pkg

echo "=== make"; unpack make-4.4.1.tar.gz; std; done_pkg
echo "=== patch"; unpack patch-2.8.tar.xz; std; done_pkg
echo "=== sed"; unpack sed-4.10.tar.xz; std; done_pkg
echo "=== tar"; unpack tar-1.35.tar.xz; std; done_pkg

echo "=== xz"; unpack xz-5.8.3.tar.xz
std --disable-static --docdir=/usr/share/doc/xz-5.8.3
rm -v $LFS/usr/lib/liblzma.la; done_pkg

echo "=== binutils pass2"; unpack binutils-2.47.tar.xz
sed '6031s/$add_dir//' -i ltmain.sh
mkdir -v build; cd build
../configure --prefix=/usr --build=$(../config.guess) --host=$LFS_TGT --disable-nls --enable-shared --enable-gprofng=no --disable-werror --enable-64-bit-bfd --enable-new-dtags --enable-default-hash-style=gnu
make && make DESTDIR=$LFS install
rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}
done_pkg

echo "=== gcc pass2"; unpack gcc-16.2.0.tar.xz
tar -xf $S/mpfr-4.2.2.tar.xz && mv -v mpfr-4.2.2 mpfr
tar -xf $S/gmp-6.3.0.tar.xz && mv -v gmp-6.3.0 gmp
tar -xf $S/mpc-1.4.1.tar.xz && mv -v mpc-1.4.1 mpc
case $(uname -m) in x86_64) sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64 ;; esac
mkdir -v build; cd build
../configure --build=$(../config.guess) --host=$LFS_TGT --target=$LFS_TGT --prefix=/usr --with-build-sysroot=$LFS --enable-default-pie --enable-default-ssp --disable-fixincludes --disable-nls --disable-multilib --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libsanitizer --disable-libssp --disable-libvtv --enable-languages=c,c++ CXX_FOR_TARGET="$LFS_TGT-gcc -nostdinc++" LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc target_configargs=gcc_cv_target_thread_file=posix
make && make DESTDIR=$LFS install
ln -sfv gcc $LFS/usr/bin/cc
done_pkg
echo "=== DONE ch6"
