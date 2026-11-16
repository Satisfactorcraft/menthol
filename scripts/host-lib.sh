# Shared settings for the host-side helpers. Source it, do not run it.
# Override with the environment: MENTHOL_HOME, MENTHOL_IMG, LFS.
MENTHOL_HOME=${MENTHOL_HOME:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)}
MENTHOL_IMG=${MENTHOL_IMG:-$MENTHOL_HOME/menthol.img}
LFS=${LFS:-/mnt/lfs}
