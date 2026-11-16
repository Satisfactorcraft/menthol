#!/bin/bash
# MentholLinux build driver: runs the build stages in order and logs each one to logs/<stage>.log
set -e
. "$(dirname "$(readlink -f "$0")")/scripts/host-lib.sh"
SCRIPTS=$MENTHOL_HOME/scripts
DESKTOP=${DESKTOP:-none}
while [ $# -gt 0 ]; do
  case $1 in
    --desktop) [ $# -ge 2 ] || { echo "--desktop needs a name: none, xfce, kde, gnome" >&2; exit 2; }; DESKTOP=$2; shift 2 ;;
    --desktop=*) DESKTOP=${1#--desktop=}; shift ;;
    *) break ;;
  esac
done
case $DESKTOP in none|xfce|kde|gnome) ;; *) echo "unknown desktop: $DESKTOP (none, xfce, kde, gnome)" >&2; exit 2 ;; esac
HOST_STAGES="ch5-a ch5-b ch6"
CHROOT_STAGES="ch7 ch8-a ch8-b ch8-c ch9 ch10-kernel boot-extras polish blfs blfs-git mpkg-setup blfs-extras hardening desktop"

usage() {
  cat << EOT
usage: build.sh [--desktop none|xfce|kde|gnome] COMMAND

  list              show the stages in build order
  mount | umount    attach/detach menthol.img at $LFS
  sync              copy scripts/ (and the host CA bundle) into the image at /lfs-scripts
  run STAGE...      run the given stages, in the order given
  all --yes         run every stage on a mounted, empty image (takes hours, rebuilds the whole system)
  test uefi|bios [VARS_FD]   boot the image in QEMU and run the checks (needs MENTHOL_TEST_PW)
  lint              syntax-check and shellcheck the scripts

Host stages (run as your user, clean environment): $HOST_STAGES
Chroot stages (run as root inside the image):      $CHROOT_STAGES

--desktop picks what the "desktop" stage installs with mpkg (default: none). The desktop
packages are not published yet, so only "none" works today.

Settings (environment): MENTHOL_IMG=$MENTHOL_IMG  LFS=$LFS
EOT
}

is_in() { local x=$1; shift; for y in "$@"; do [ "$x" = "$y" ] && return 0; done; return 1; }

sync_scripts() {
  mountpoint -q "$LFS" || { echo "$LFS is not mounted, run: build.sh mount" >&2; exit 1; }
  if [ ! -d "$LFS/lfs-scripts" ]; then
    sudo -n /usr/bin/mkdir -p "$LFS/lfs-scripts"
    sudo -n /usr/bin/chown "$(id -un)" "$LFS/lfs-scripts"
  fi
  cp -r "$SCRIPTS"/. "$LFS/lfs-scripts/"
  for ca in /etc/ssl/certs/ca-certificates.crt /etc/ssl/cert.pem /etc/pki/tls/certs/ca-bundle.crt; do
    if [ -r "$ca" ]; then cp "$ca" "$LFS/lfs-scripts/ca-bundle.pem"; break; fi
  done
  echo "synced scripts to $LFS/lfs-scripts"
}

run_stage() {
  local st=$1 log=$MENTHOL_HOME/logs/$1.log rc=0
  mkdir -p "$MENTHOL_HOME/logs"
  echo ">>> $st (log: $log)"
  if is_in "$st" $HOST_STAGES; then
    mountpoint -q "$LFS" || { echo "$LFS is not mounted, run: build.sh mount" >&2; exit 1; }
    env -i HOME="$HOME" TERM="$TERM" LFS="$LFS" /bin/bash "$SCRIPTS/$st.sh" > "$log" 2>&1 || rc=$?
  elif is_in "$st" $CHROOT_STAGES; then
    sync_scripts > /dev/null
    local vars=()
    if [ "$st" = boot-extras ]; then
      local loop
      loop=$(losetup -j "$MENTHOL_IMG" -O NAME -n | head -n 1)
      [ -n "$loop" ] || { echo "no loop device for $MENTHOL_IMG" >&2; exit 1; }
      vars=("LOOPDEV=$loop" "ROOT_PARTUUID=$(lsblk -no PARTUUID "${loop}p2")")
    fi
    if [ "$st" = desktop ]; then
      vars=("DESKTOP=$DESKTOP" "MENTHOL_DNS=$(awk '/^nameserver/ {print $2}' /etc/resolv.conf 2> /dev/null | paste -sd' ')")
    fi
    [ "$st" = hardening ] && [ -n "$SSH_KEY_ONLY" ] && vars+=("SSH_KEY_ONLY=$SSH_KEY_ONLY")
    if [ "$st" = ch7 ]; then
      [ "$(stat -c %U "$LFS/usr")" = root ] || { echo "run first: sudo chown -R root:root $LFS/{usr,lib,lib64,var,etc,bin,sbin,tools}" >&2; exit 1; }
      [ -n "$CH7_FORCE" ] && vars+=("CH7_FORCE=$CH7_FORCE")
    fi
    "$SCRIPTS/chroot.sh" "/lfs-scripts/$st.sh" "${vars[@]}" > "$log" 2>&1 || rc=$?
  else
    echo "unknown stage: $st (see: build.sh list)" >&2; exit 2
  fi
  if [ $rc -ne 0 ]; then
    echo "!!! $st FAILED (exit $rc), last lines of $log:" >&2
    tail -n 25 "$log" >&2
    exit $rc
  fi
  echo "<<< $st ok"
}

case ${1:-} in
  list) printf '%s\n' $HOST_STAGES $CHROOT_STAGES ;;
  mount) "$SCRIPTS/mount-image.sh" ;;
  umount) "$SCRIPTS/umount-image.sh" ;;
  sync) sync_scripts ;;
  run)
    shift
    [ $# -ge 1 ] || { usage >&2; exit 2; }
    for st in "$@"; do is_in "$st" $HOST_STAGES $CHROOT_STAGES || { echo "unknown stage: $st (see: build.sh list)" >&2; exit 2; }; done
    for st in "$@"; do run_stage "$st"; done ;;
  all)
    [ "${2:-}" = --yes ] || { echo "this rebuilds the whole system from chapter 5 on; confirm with: build.sh all --yes" >&2; exit 2; }
    for st in $HOST_STAGES $CHROOT_STAGES; do run_stage "$st"; done ;;
  test)
    shift
    exec python3 "$SCRIPTS/vmtest.py" "$@" ;;
  lint)
    rc=0
    for f in "$MENTHOL_HOME"/*.sh "$SCRIPTS"/*.sh "$SCRIPTS"/files/*; do bash -n "$f" || rc=1; done
    python3 -m py_compile "$SCRIPTS/vmtest.py" || rc=1
    if command -v shellcheck > /dev/null; then
      shellcheck -S error -s bash "$MENTHOL_HOME"/*.sh "$SCRIPTS"/*.sh "$SCRIPTS"/files/* || rc=1
    else
      echo "shellcheck is not installed, only the syntax was checked"
    fi
    [ $rc -eq 0 ] && echo "lint ok"
    exit $rc ;;
  ""|-h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
