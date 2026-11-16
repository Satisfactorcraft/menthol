#!/bin/bash
. /lfs-scripts/ch8-lib.sh
unpack coreutils-9.11.tar.xz
patch -Np1 -i $S/coreutils-9.11-i18n-1.patch
autoreconf -fv; automake -af
FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr
make
make install
if [ -e /usr/bin/chroot ]; then
  mv -v /usr/bin/chroot /usr/sbin
  mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
  sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
fi
done_pkg

unpack diffutils-3.12.tar.xz; std; done_pkg
unpack findutils-4.11.0.tar.xz; std --localstatedir=/var/lib/locate; done_pkg
unpack groff-1.24.1.tar.gz
PAGE=A4 ./configure --prefix=/usr
make -j1
make install
done_pkg

unpack grub-2.14.tar.xz
unset {C,CPP,CXX,LD}FLAGS
sed 's/--image-base/--nonexist-linker-option/' -i configure
./configure --prefix=/usr --sysconfdir=/etc --disable-efiemu --disable-werror
make
make install
make clean
./configure --prefix=/usr --sysconfdir=/etc --target=x86_64 --with-platform=efi --disable-efiemu --disable-werror
make
make install
done_pkg

unpack gzip-1.14.tar.xz; std; done_pkg

unpack iproute2-7.1.0.tar.xz
sed -i /ARPD/d Makefile
rm -fv man/man8/arpd.8
make NETNS_RUN_DIR=/run/netns
make SBINDIR=/usr/sbin install
install -vDm644 COPYING README* -t /usr/share/doc/iproute2-7.1.0
done_pkg

unpack kbd-2.10.0.tar.xz
patch -Np1 -i $S/kbd-2.10.0-backspace-1.patch
sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
std --disable-vlock
cp -R -v docs/doc -T /usr/share/doc/kbd-2.10.0
done_pkg

unpack libpipeline-1.5.8.tar.gz; std; done_pkg
unpack make-4.4.1.tar.gz; std; done_pkg
unpack patch-2.8.tar.xz; std; done_pkg
unpack tar-1.35.tar.xz
patch -Np1 -i $S/tar-1.35-acl_fix-1.patch
FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr
make
make install
make -C doc install-html docdir=/usr/share/doc/tar-1.35
done_pkg

unpack texinfo-7.3.tar.xz
std
make TEXMF=/usr/share/texmf install-tex
pushd /usr/share/info
  rm -v dir
  for f in *; do install-info $f dir 2>/dev/null; done
popd
done_pkg

unpack vim-9.2.1025.tar.gz
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
std
ln -sfv vim /usr/bin/vi
for L in /usr/share/man/{,*/}man1/vim.1; do ln -sfv vim.1 $(dirname $L)/vi.1; done
ln -sfv ../vim/vim92/doc /usr/share/doc/vim-9.2.1025
cat > /etc/vimrc << "EOT"
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1

set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOT
done_pkg

unpack markupsafe-3.0.3.tar.gz; pipinst Markupsafe; done_pkg
unpack jinja2-3.1.6.tar.gz; pipinst Jinja2; done_pkg

unpack systemd-261.2.tar.gz
sed -e 's/GROUP="render"/GROUP="video"/' -e 's/GROUP="sgx", //' -i rules.d/50-udev-default.rules.in
mkdir -p build; cd build
meson setup .. --prefix=/usr --buildtype=release -D default-dnssec=no -D firstboot=false -D install-tests=false -D ldconfig=false -D sysusers=false -D rpmmacrosdir=no -D homed=disabled -D man=disabled -D mode=release -D pamconfdir=no -D dev-kvm-mode=0660 -D nobody-group=nogroup -D sysupdate=disabled -D ukify=disabled -D docdir=/usr/share/doc/systemd-261.2
ninja
ninja install
tar -xf $S/systemd-man-pages-261.2.tar.xz --no-same-owner --strip-components=1 -C /usr/share/man
systemd-machine-id-setup
systemctl preset-all
done_pkg

unpack dbus-1.16.2.tar.xz
mkdir build; cd build
meson setup --prefix=/usr --buildtype=release --wrap-mode=nofallback ..
ninja
ninja install
ln -sfv /etc/machine-id /var/lib/dbus
done_pkg

unpack man-db-2.13.1.tar.xz
std --docdir=/usr/share/doc/man-db-2.13.1 --sysconfdir=/etc --disable-setuid --enable-cache-owner=bin --with-browser=/usr/bin/lynx --with-vgrind=/usr/bin/vgrind --with-grap=/usr/bin/grap
done_pkg

unpack procps-ng-4.0.7.tar.xz
std --docdir=/usr/share/doc/procps-ng-4.0.7 --disable-static --disable-kill --enable-watch8bit --with-systemd
done_pkg

unpack util-linux-2.42.2.tar.xz
./configure --bindir=/usr/bin --libdir=/usr/lib --runstatedir=/run --sbindir=/usr/sbin --disable-chfn-chsh --disable-login --disable-nologin --disable-su --disable-setpriv --disable-runuser --disable-pylibmount --disable-liblastlog2 --disable-static --without-python ADJTIME_PATH=/var/lib/hwclock/adjtime --docdir=/usr/share/doc/util-linux-2.42.2
make
touch /etc/fstab
make install
done_pkg

unpack e2fsprogs-1.47.4.tar.gz
mkdir -v build; cd build
../configure --prefix=/usr --sysconfdir=/etc --enable-elf-shlibs --disable-libblkid --disable-libuuid --disable-uuidd --disable-fsck
make
make install
rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
gunzip -v /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
makeinfo -o doc/com_err.info ../lib/et/com_err.texinfo
install -v -m644 doc/com_err.info /usr/share/info
install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info
sed 's/metadata_csum_seed,//' -i /etc/mke2fs.conf
done_pkg

echo "=== cleanup"
find /tmp -mindepth 1 -delete
find /usr/lib /usr/libexec -name \*.la -delete
find /usr -depth -name $(uname -m)-lfs-linux-gnu\* | xargs rm -rf
echo "=== DONE ch8-c"
