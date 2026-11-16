. /lfs-scripts/ch8-lib.sh
unpack git-2.55.0.tar.xz
./configure --prefix=/usr --with-gitconfig=/etc/gitconfig --with-python=python3 --with-libpcre2
make NO_RUST=1
make NO_RUST=1 perllibdir=/usr/lib/perl5/5.44/site_perl install
done_pkg
echo "=== DONE blfs-git"
