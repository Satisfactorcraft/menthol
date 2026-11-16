#!/bin/bash
set -eE
trap 'echo "FAILED: line $LINENO: $BASH_COMMAND" >&2' ERR
# --- MentholLinux configuration (LFS chapter 9 + 11 branding)
echo menthol > /etc/hostname
cat > /etc/hosts << "EOT"
# Begin /etc/hosts
127.0.0.1 localhost menthol
::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters
# End /etc/hosts
EOT

# Network: DHCP on all ethernet devices via systemd-networkd, DNS via systemd-resolved
mkdir -pv /etc/systemd/network
cat > /etc/systemd/network/10-eth-dhcp.network << "EOT"
[Match]
Name=en*

[Network]
DHCP=ipv4

[DHCPv4]
UseDomains=true
EOT
ln -sfv /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
systemctl enable systemd-networkd systemd-resolved
systemctl disable systemd-networkd-wait-online || true

# Locale, console, shells, readline
cat > /etc/locale.conf << "EOT"
LANG=en_US.UTF-8
EOT
cat > /etc/vconsole.conf << "EOT"
KEYMAP=de-latin1
EOT
cat > /etc/profile << "EOT"
# Begin /etc/profile

for i in $(locale); do
  unset ${i%=*}
done

if [[ "$TERM" = linux ]]; then
  export LANG=C.UTF-8
else
  source /etc/locale.conf

  for i in $(locale); do
    key=${i%=*}
    if [[ -v $key ]]; then
      export $key
    fi
  done
fi

# End /etc/profile
EOT
cat > /etc/shells << "EOT"
# Begin /etc/shells

/bin/sh
/bin/bash

# End /etc/shells
EOT
cat > /etc/inputrc << "EOT"
# Begin /etc/inputrc
set horizontal-scroll-mode Off
set meta-flag On
set input-meta On
set convert-meta Off
set output-meta On
set bell-style none
"\eOd": backward-word
"\eOc": forward-word
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert
"\eOH": beginning-of-line
"\eOF": end-of-line
"\e[H": beginning-of-line
"\e[F": end-of-line
# End /etc/inputrc
EOT
mkdir -pv /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/noclear.conf << "EOT"
[Service]
TTYVTDisallocate=no
EOT

# fstab by label (the image labels: MentholRoot, MENTHOLEFI)
cat > /etc/fstab << "EOT"
# Begin /etc/fstab
# file system        mount-point  type  options                                  dump fsck
LABEL=MentholRoot    /            ext4  defaults                                 1    1
LABEL=MENTHOLEFI     /boot/efi    vfat  rw,relatime,codepage=437,iocharset=iso8859-1  0 2
# End /etc/fstab
EOT

# MentholLinux branding
echo "1.0" > /etc/menthol-release
cat > /etc/lsb-release << "EOT"
DISTRIB_ID="MentholLinux"
DISTRIB_RELEASE="1.0"
DISTRIB_CODENAME="menthol"
DISTRIB_DESCRIPTION="MentholLinux (LFS 13.1 systemd)"
EOT
cat > /etc/os-release << "EOT"
NAME="MentholLinux"
VERSION="1.0"
ID=menthol
ID_LIKE=lfs
PRETTY_NAME="MentholLinux 1.0 (LFS 13.1 systemd)"
VERSION_CODENAME="menthol"
HOME_URL="https://github.com/Satisfactorcraft/menthol"
RELEASE_TYPE="stable"
EOT
echo "=== DONE ch9"
