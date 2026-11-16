# Install the selected desktop with mpkg. NOT run against an image yet.
#   DESKTOP=none|xfce|kde|gnome   (build.sh --desktop NAME; an installer can call this the same way later)
# The desktop is the package "desktop-<name>" from the mpkg repositories, a meta package that
# depends on everything the desktop needs. No such packages have been published yet.
set -e
DESKTOP=${DESKTOP:-none}
case $DESKTOP in
  none|xfce|kde|gnome) ;;
  *) echo "desktop: unknown desktop '$DESKTOP' (none, xfce, kde, gnome)" >&2; exit 2 ;;
esac
mkdir -p /etc/menthol
if [ "$DESKTOP" = none ]; then
  echo none > /etc/menthol/desktop
  echo "=== DONE desktop (none)"
  exit 0
fi
command -v mpkg > /dev/null || { echo "desktop: mpkg is not installed, run the mpkg-setup stage first" >&2; exit 1; }
# In the chroot /etc/resolv.conf points at systemd-resolved, which is not running there
if [ ! -e /etc/resolv.conf ] && [ -n "$MENTHOL_DNS" ]; then
  mkdir -p /run/systemd/resolve
  for ns in $MENTHOL_DNS; do echo "nameserver $ns"; done > /run/systemd/resolve/stub-resolv.conf
fi
mpkg update
if ! mpkg -y install "desktop-$DESKTOP"; then
  echo "desktop: could not install desktop-$DESKTOP. Is it published in a repository from /etc/mpkg/repos.conf?" >&2
  exit 1
fi
echo "$DESKTOP" > /etc/menthol/desktop
echo "=== DONE desktop ($DESKTOP)"
