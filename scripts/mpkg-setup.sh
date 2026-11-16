# Install mpkg, the MentholLinux package manager. NOT run against an image yet.
set -e
install -v -m755 /lfs-scripts/files/mpkg /usr/bin/mpkg
install -v -d -m755 /etc/mpkg /var/lib/mpkg/installed /var/lib/mpkg/lists /var/cache/mpkg
if [ ! -f /etc/mpkg/repos.conf ]; then
  cat > /etc/mpkg/repos.conf << "EOT"
# mpkg repositories, one per line: NAME URL
# The URL is a directory with mpkg.index and the .tar.xz packages (https://, file:// or a local path).
menthol https://github.com/Satisfactorcraft/menthol/releases/download/packages
EOT
fi
# The public key of the default repository: with it, unsigned or tampered package lists are rejected
if [ -f /lfs-scripts/files/mpkg-menthol.pub ]; then
  install -v -D -m644 /lfs-scripts/files/mpkg-menthol.pub /etc/mpkg/keys/menthol.pub
else
  echo "--- no scripts/files/mpkg-menthol.pub: package lists will NOT be signature-checked"
fi
mpkg version
echo "=== DONE mpkg-setup"
