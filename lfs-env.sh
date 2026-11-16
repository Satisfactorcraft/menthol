# Source this file: . <repo>/lfs-env.sh
set +h
umask 022
export LFS=${LFS:-/mnt/lfs}
export LC_ALL=POSIX
export LFS_TGT=$(uname -m)-lfs-linux-gnu
export PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
export PATH=$LFS/tools/bin:$PATH
export CONFIG_SITE=$LFS/usr/share/config.site
export MAKEFLAGS=-j$(nproc)
