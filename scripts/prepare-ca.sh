#!/bin/bash
# Host side. Copy the host's CA bundle into the image's script directory for blfs.sh.
# Re-run it to refresh the bundle, then re-run the install step of blfs.sh (or copy the file to
# /etc/ssl/certs/ca-certificates.crt in the image).
set -e
DEST=/mnt/lfs/lfs-scripts/ca-bundle.pem
[ -d "$(dirname "$DEST")" ] || { echo "ERROR: $(dirname "$DEST") missing; mount the image first" >&2; exit 1; }
for c in /etc/ssl/certs/ca-certificates.crt /etc/ca-certificates/extracted/tls-ca-bundle.pem /etc/pki/tls/certs/ca-bundle.crt; do
  if [ -r "$c" ]; then
    cp -L "$c" "$DEST"
    echo "copied $(readlink -f "$c") -> $DEST ($(wc -c < "$DEST") bytes)"
    exit 0
  fi
done
echo "ERROR: no CA bundle found on this host" >&2
exit 1
