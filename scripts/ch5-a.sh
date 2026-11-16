#!/bin/bash
set -e
. /home/jan/LFS/lfs-env.sh
mkdir -p $LFS/build && cd $LFS/build
echo "=== binutils pass1"
rm -rf binutils-2.47 && tar -xf $LFS/sources/binutils-2.47.tar.xz && cd binutils-2.47
mkdir -v build && cd build
../configure --prefix=$LFS/tools --with-sysroot=$LFS --target=$LFS_TGT --disable-nls --enable-gprofng=no --disable-werror --enable-new-dtags --enable-default-hash-style=gnu
make && make install
cd $LFS/build && rm -rf binutils-2.47
echo "=== gcc pass1"
tar -xf $LFS/sources/gcc-16.2.0.tar.xz && cd gcc-16.2.0
tar -xf $LFS/sources/mpfr-4.2.2.tar.xz && mv -v mpfr-4.2.2 mpfr
tar -xf $LFS/sources/gmp-6.3.0.tar.xz && mv -v gmp-6.3.0 gmp
tar -xf $LFS/sources/mpc-1.4.1.tar.xz && mv -v mpc-1.4.1 mpc
case $(uname -m) in x86_64) sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64 ;; esac
mkdir -v build && cd build
../configure --target=$LFS_TGT --prefix=$LFS/tools --with-glibc-version=2.44 --with-sysroot=$LFS --with-newlib --without-headers --enable-default-pie --enable-default-ssp --disable-fixincludes --disable-nls --disable-shared --disable-multilib --disable-threads --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libssp --disable-libvtv --disable-libstdcxx --enable-languages=c,c++
make && make install
cd ..
cat gcc/{limitx,glimits,limity}.h > $($LFS_TGT-gcc -print-file-name=include)/limits.h
cd $LFS/build && rm -rf gcc-16.2.0
echo "=== DONE ch5-a"
