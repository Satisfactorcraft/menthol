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
mpkg version
echo "=== DONE mpkg-setup"
