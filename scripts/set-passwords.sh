#!/bin/bash
# Host side. Set the passwords of root and menthol in the mounted image and, by default,
# force a change at the first login. Passwords come from the environment, never from the repo.
#   MENTHOL_ROOT_PW=... MENTHOL_USER_PW=... scripts/set-passwords.sh [--no-expire]
set -eE
: "${MENTHOL_ROOT_PW:?set MENTHOL_ROOT_PW}"
: "${MENTHOL_USER_PW:?set MENTHOL_USER_PW}"
L=/mnt/lfs
mountpoint -q $L || { echo "ERROR: image not mounted (run scripts/mount-image.sh)" >&2; exit 1; }
CH="sudo -n /usr/bin/chroot $L /usr/bin/env -i PATH=/usr/bin:/usr/sbin"
printf '%s\n' "root:$MENTHOL_ROOT_PW" "menthol:$MENTHOL_USER_PW" | $CH /usr/sbin/chpasswd
if [ "$1" != "--no-expire" ]; then
  $CH /usr/bin/chage -d 0 root
  $CH /usr/bin/chage -d 0 menthol
  echo "passwords set; both must be changed at the first login"
else
  echo "passwords set (no forced change)"
fi
