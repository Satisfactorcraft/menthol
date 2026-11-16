#!/bin/bash
set -eE
trap 'echo "FAILED: line $LINENO: $BASH_COMMAND" >&2' ERR
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
# /etc/motd is printed by login(1) (MOTD_FILE in /etc/login.defs) and by sshd, not here
EOT
if ! grep -q "MentholLinux: per-package shell snippets" /etc/profile; then
cat >> /etc/profile << "EOT"

# MentholLinux: per-package shell snippets
for f in /etc/profile.d/*.sh; do [ -r "$f" ] && . "$f"; done
unset f
EOT
fi
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
cp -n /etc/skel/.bash_profile /etc/skel/.bashrc /root/

# Normal user in wheel (password set separately)
getent group wheel >/dev/null
id menthol >/dev/null 2>&1 || useradd -m -G wheel -s /bin/bash menthol
echo "=== DONE polish"
