#!/bin/bash
# Download the LFS source tarballs and patches and verify them against the book's md5sums.
# usage: fetch-sources.sh [--only PATTERN] [DEST]     (DEST defaults to $LFS/sources if mounted, else ./sources)
# Book location: LFS_BOOK_URL (default: the 13.1 systemd book)
set -e
. "$(dirname "$(readlink -f "$0")")/host-lib.sh"
BOOK=${LFS_BOOK_URL:-https://www.linuxfromscratch.org/lfs/view/13.1-systemd}
only=""
if [ "${1:-}" = --only ]; then only=${2:?--only needs a pattern}; shift 2; fi
if [ -n "${1:-}" ]; then DEST=$1; elif mountpoint -q "$LFS"; then DEST=$LFS/sources; else DEST=$MENTHOL_HOME/sources; fi
mkdir -p "$DEST"; cd "$DEST"
curl -fsSL -o wget-list "$BOOK/wget-list-systemd"
curl -fsSL -o md5sums "$BOOK/md5sums"

md5_ok() { grep -F "  $1" md5sums | grep -E "  $1\$" | md5sum -c --status 2> /dev/null; }
have=0; got=0; bad=""
while IFS= read -r url; do
  [ -n "$url" ] || continue
  f=${url##*/}
  if [ -n "$only" ]; then case $f in *$only*) ;; *) continue ;; esac; fi
  if [ -f "$f" ] && md5_ok "$f"; then have=$((have + 1)); continue; fi
  echo "fetching $f"
  if curl -fL --retry 3 -sS -o "$f.part" "$url" && mv "$f.part" "$f" && md5_ok "$f"; then
    got=$((got + 1))
  else
    rm -f "$f.part"; bad="$bad $f"
  fi
done < wget-list
echo "sources in $DEST: $have already there, $got downloaded"
if [ -n "$bad" ]; then echo "FAILED (download or md5 mismatch):$bad" >&2; exit 1; fi
