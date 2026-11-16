#!/bin/bash
set -e
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lfs-env.sh"
cd $LFS/build
echo "=== linux headers"
tar -xf $LFS/sources/linux-7.1.8.tar.xz && cd linux-7.1.8
make mrproper && make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include $LFS/usr
cd $LFS/build && rm -rf linux-7.1.8
echo "=== glibc"
case $(uname -m) in x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64; ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3 ;; esac
tar -xf $LFS/sources/glibc-2.44.tar.xz && cd glibc-2.44
patch -Np1 -i $LFS/sources/glibc-fhs-1.patch
patch -Np1 -i $LFS/sources/glibc-2.44-upstream_fixes-1.patch
mkdir -v build && cd build
echo "rootsbindir=/usr/sbin" > configparms
../configure --prefix=/usr --host=$LFS_TGT --build=$(../scripts/config.guess) --disable-nscd libc_cv_slibdir=/usr/lib --enable-kernel=5.10
make && make DESTDIR=$LFS install
sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd
echo "--- sanity check"
echo 'int main(){}' | $LFS_TGT-gcc -x c - -v -Wl,--verbose &> dummy.log
$LFS_TGT-readelf -l a.out | grep ': /lib' | tee /dev/stderr | grep -q 'ld-linux-x86-64.so.2'
grep -E -o "$LFS/lib.*/S?crt[1in].*succeeded" dummy.log
grep -B3 "^ $LFS/usr/include" dummy.log
grep "/lib.*/libc.so.6 " dummy.log
grep found dummy.log
rm -v a.out dummy.log
cd $LFS/build && rm -rf glibc-2.44
echo "=== libstdc++"
tar -xf $LFS/sources/gcc-16.2.0.tar.xz && cd gcc-16.2.0
mkdir -v build && cd build
../libstdc++-v3/configure --host=$LFS_TGT --build=$(../config.guess) CXX=$LFS_TGT-gcc --prefix=/usr --disable-multilib --disable-nls --disable-libstdcxx-pch --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/16.2.0
make && make DESTDIR=$LFS install
rm -v $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la
cd $LFS/build && rm -rf gcc-16.2.0
echo "=== DONE ch5-b"
