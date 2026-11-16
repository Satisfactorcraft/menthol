# Build the mpkg packages from the recipes in /lfs-scripts/packages and install them.
# The packages and mpkg.index end up in /lfs-scripts/out, ready to be signed and uploaded.
# NOT run against an image yet.
#   PACKAGES="nano tmux"   build only these (default: everything in packages/order.txt)
# No "set -e" here: mpkg make must not run inside an if/|| or build errors would be ignored.
REC=/lfs-scripts/packages
OUT=/lfs-scripts/out
command -v mpkg > /dev/null || { echo "packages: mpkg is not installed, run the mpkg-setup stage first" >&2; exit 1; }
mkdir -p "$OUT" || exit 1
# In the chroot /etc/resolv.conf points at systemd-resolved, which is not running there
if [ ! -e /etc/resolv.conf ] && [ -n "$MENTHOL_DNS" ]; then
  mkdir -p /run/systemd/resolve
  for ns in $MENTHOL_DNS; do echo "nameserver $ns"; done > /run/systemd/resolve/stub-resolv.conf
fi
list=${PACKAGES:-$(grep -Ev '^[[:space:]]*(#|$)' "$REC/order.txt")}
built=""; skipped=""; failed=""
for p in $list; do
  [ -f "$REC/$p/recipe" ] || { echo "packages: no recipe for $p" >&2; failed="$failed $p"; continue; }
  ver=$(sed -n 's/^version=//p' "$REC/$p/recipe" | head -n 1)
  rel=$(sed -n 's/^release=//p' "$REC/$p/recipe" | head -n 1)
  if [ "$(mpkg list | awk -v n="$p" '$1 == n {print $2}')" = "$ver-${rel:-1}" ] && ls "$OUT/$p-$ver-${rel:-1}"-*.tar.xz > /dev/null 2>&1; then
    skipped="$skipped $p"; continue
  fi
  echo "=== $p $ver"
  mpkg -y make -o "$OUT" --install "$REC/$p"
  rc=$?
  if [ $rc -eq 0 ]; then built="$built $p"; else failed="$failed $p"; fi
done
mpkg index "$OUT"
echo "=== built:     ${built:- none}"
echo "=== unchanged: ${skipped:- none}"
echo "=== FAILED:    ${failed:- none}"
[ -z "$failed" ] || exit 1
echo "=== DONE packages"
