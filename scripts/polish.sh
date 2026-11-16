set -e
# Shell experience: prompt, aliases, MOTD
mkdir -p /etc/profile.d
cat > /etc/profile.d/menthol.sh << "EOT"
# MentholLinux shell defaults
case $- in *i*) ;; *) return 0 ;; esac
if [ "$(id -u)" -eq 0 ]; then
  PS1='\[\e[1;31m\]\u\[\e[0m\]@\[\e[1;36m\]\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]# '
else
  PS1='\[\e[1;32m\]\u\[\e[0m\]@\[\e[1;36m\]\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
fi
export PS1
alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'
if [ -z "$MENTHOL_MOTD_SHOWN" ] && [ -r /etc/motd ] && shopt -q login_shell; then
  cat /etc/motd
  [ -e /etc/menthol/setup-done ] || echo "  First boot? Run 'sudo menthol-setup' to set passwords, hostname and timezone."
  export MENTHOL_MOTD_SHOWN=1
fi
EOT
grep -q 'MentholLinux: per-package shell snippets' /etc/profile || cat >> /etc/profile << "EOT"

# MentholLinux: per-package shell snippets
for f in /etc/profile.d/*.sh; do [ -r "$f" ] && . "$f"; done
unset f
EOT
cat > /etc/motd << "EOT"

  __  __            _   _           _
 |  \/  | ___ _ __ | |_| |__   ___ | |
 | |\/| |/ _ \ '_ \| __| '_ \ / _ \| |
 | |  | |  __/ | | | |_| | | | (_) | |
 |_|  |_|\___|_| |_|\__|_| |_|\___/|_|   Linux 1.0  (LFS 13.1, systemd)

EOT
cat > /etc/issue << "EOT"
MentholLinux 1.0 - \n - \l

EOT
mkdir -p /etc/skel
cat > /etc/skel/.bash_profile << "EOT"
[ -f ~/.bashrc ] && . ~/.bashrc
EOT
cat > /etc/skel/.bashrc << "EOT"
# ~/.bashrc - interactive non-login shells
[ -r /etc/profile.d/menthol.sh ] && . /etc/profile.d/menthol.sh
EOT
cp /etc/skel/.bash_profile /etc/skel/.bashrc /root/

# Normal user in wheel (password set separately)
getent group wheel >/dev/null || groupadd -g 97 wheel
id menthol >/dev/null 2>&1 || useradd -m -G wheel -s /bin/bash menthol
# menthol-info (system summary tool)
# menthol-setup (first-boot setup)
for f in menthol-info menthol-setup; do
  if [ -f /lfs-scripts/files/$f ]; then install -v -m755 /lfs-scripts/files/$f /usr/bin/$f; fi
done
echo "=== DONE polish"
