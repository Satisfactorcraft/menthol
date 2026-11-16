# LFS chapter 7 (inside the chroot): directory tree, essential files, additional temporary tools.
#
# RECONSTRUCTED from the LFS 13.1 systemd book. The script that built the current image was
# written inside the image and never committed, so this one has not been run yet.
#
# Before this script, on the host (book section 7.2):
#   sudo chown -R root:root /mnt/lfs/{usr,lib,lib64,var,etc,bin,sbin,tools}
# It refuses to run on a system that already has /etc/passwd, because it would wipe
# the users created later (menthol, sshd). Set CH7_FORCE=1 to run it anyway.
if [ -e /etc/passwd ] && [ "$CH7_FORCE" != 1 ]; then
  echo "ch7: /etc/passwd already exists, this system is past chapter 7 (CH7_FORCE=1 overrides)" >&2
  exit 1
fi
. /lfs-scripts/ch8-lib.sh

echo "=== 7.5 directories"
mkdir -pv /{boot,home,mnt,opt,srv}
mkdir -pv /etc/{opt,sysconfig}
mkdir -pv /lib/firmware
mkdir -pv /media/{floppy,cdrom}
mkdir -pv /usr/{,local/}{include,src}
mkdir -pv /usr/lib/locale
mkdir -pv /usr/local/{bin,lib,sbin}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv /usr/{,local/}share/man/man{1..8}
mkdir -pv /var/{cache,local,log,mail,opt,spool}
mkdir -pv /var/lib/{color,misc,locate}
ln -sfv /run /var/run
ln -sfv /run/lock /var/lock
install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp

echo "=== 7.6 essential files"
ln -sfv /proc/self/mounts /etc/mtab
cat > /etc/hosts << "EOT"
127.0.0.1  localhost menthol
::1        localhost
EOT
cat > /etc/passwd << "EOT"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
systemd-journal-gateway:x:73:73:systemd Journal Gateway:/:/usr/bin/false
systemd-journal-remote:x:74:74:systemd Journal Remote:/:/usr/bin/false
systemd-journal-upload:x:75:75:systemd Journal Upload:/:/usr/bin/false
systemd-network:x:76:76:systemd Network Management:/:/usr/bin/false
systemd-resolve:x:77:77:systemd Resolver:/:/usr/bin/false
systemd-timesync:x:78:78:systemd Time Synchronization:/:/usr/bin/false
systemd-coredump:x:79:79:systemd Core Dumper:/:/usr/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/usr/bin/false
systemd-oom:x:81:81:systemd Out Of Memory Daemon:/:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOT
cat > /etc/group << "EOT"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
systemd-journal:x:23:
input:x:24:
mail:x:34:
kvm:x:61:
systemd-journal-gateway:x:73:
systemd-journal-remote:x:74:
systemd-journal-upload:x:75:
systemd-network:x:76:
systemd-resolve:x:77:
systemd-timesync:x:78:
systemd-coredump:x:79:
uuidd:x:80:
systemd-oom:x:81:
wheel:x:97:
users:x:999:
nogroup:x:65534:
EOT
localedef -i C -f UTF-8 C.UTF-8
# No "tester" user: all test suites are skipped.
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664 /var/log/lastlog
chmod -v 600 /var/log/btmp

unpack gettext-1.0.tar.xz
./configure --disable-shared
make
cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
done_pkg

unpack bison-3.8.2.tar.xz
std --docdir=/usr/share/doc/bison-3.8.2
done_pkg

unpack perl-5.44.0.tar.xz
sh Configure -des -D prefix=/usr -D vendorprefix=/usr -D useshrplib \
  -D privlib=/usr/lib/perl5/5.44/core_perl -D archlib=/usr/lib/perl5/5.44/core_perl \
  -D sitelib=/usr/lib/perl5/5.44/site_perl -D sitearch=/usr/lib/perl5/5.44/site_perl \
  -D vendorlib=/usr/lib/perl5/5.44/vendor_perl -D vendorarch=/usr/lib/perl5/5.44/vendor_perl
make && make install
done_pkg

unpack Python-3.14.7.tar.xz
std --enable-shared --without-ensurepip --without-static-libpython
done_pkg

unpack texinfo-7.3.tar.xz
std
done_pkg

unpack util-linux-2.42.2.tar.xz
mkdir -pv /var/lib/hwclock
./configure --libdir=/usr/lib --runstatedir=/run --disable-chfn-chsh --disable-login --disable-nologin \
  --disable-su --disable-setpriv --disable-runuser --disable-pylibmount --disable-static \
  --disable-liblastlog2 --without-python ADJTIME_PATH=/var/lib/hwclock/adjtime \
  --docdir=/usr/share/doc/util-linux-2.42.2
make && make install
done_pkg

echo "=== 7.13 cleanup"
rm -rf /usr/share/{info,man,doc}/*
find /usr/{lib,libexec} -name \*.la -delete
rm -rf /tools
echo "=== DONE ch7"
