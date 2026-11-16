# Security defaults: sysctl, sshd, and an nftables firewall. NOT run or tested yet.
#   SSH_KEY_ONLY=1   also turn off password logins over SSH (put a key in ~/.ssh/authorized_keys first!)
# The firewall is only enabled when nft is installed (packages stage, or: mpkg install nftables) and the installed kernel
# has nf_tables (ch10-kernel.sh enables it, so that needs a kernel rebuild on an older image).
set -e

echo "=== sysctl"
mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/50-menthol.conf << "EOT"
# MentholLinux security defaults (a leading "-" ignores keys the kernel does not have)
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
-kernel.yama.ptrace_scope = 1
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
EOT

echo "=== sshd"
if [ -f /etc/ssh/sshd_config ]; then
  mkdir -p /etc/ssh/sshd_config.d
  # sshd uses the first value it sees, so the Include has to be the first line
  grep -q '^Include /etc/ssh/sshd_config.d/\*.conf' /etc/ssh/sshd_config ||
    sed -i '1i Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config
  cat > /etc/ssh/sshd_config.d/50-menthol.conf << "EOT"
PermitRootLogin no
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
EOT
  if [ "$SSH_KEY_ONLY" = 1 ]; then
    cat >> /etc/ssh/sshd_config.d/50-menthol.conf << "EOT"
PasswordAuthentication no
KbdInteractiveAuthentication no
EOT
    echo "password logins over SSH are OFF"
  fi
  /usr/sbin/sshd -G > /dev/null || echo "WARNING: sshd does not accept its configuration, check /etc/ssh" >&2
else
  echo "--- skip sshd (OpenSSH is not installed)"
fi

echo "=== firewall"
cat > /etc/nftables.conf << "EOT"
#!/usr/sbin/nft -f
# MentholLinux firewall: drop incoming traffic except SSH, ping and replies
flush ruleset

table inet filter {
  chain input {
    type filter hook input priority filter; policy drop;
    ct state established,related accept
    ct state invalid drop
    iif "lo" accept
    meta l4proto icmp accept
    meta l4proto ipv6-icmp accept
    udp dport 546 ip6 saddr fe80::/10 accept comment "DHCPv6 client"
    tcp dport 22 ct state new limit rate 15/minute burst 10 packets accept comment "SSH"
  }
  chain forward {
    type filter hook forward priority filter; policy drop;
  }
  chain output {
    type filter hook output priority filter; policy accept;
  }
}
EOT
cat > /usr/lib/systemd/system/nftables.service << "EOT"
[Unit]
Description=nftables firewall
Documentation=man:nft(8)
Wants=network-pre.target
Before=network-pre.target shutdown.target
Conflicts=shutdown.target
DefaultDependencies=no
ConditionPathExists=/etc/nftables.conf

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/nft -f /etc/nftables.conf
ExecReload=/usr/sbin/nft -f /etc/nftables.conf
ExecStop=/usr/sbin/nft flush ruleset

[Install]
WantedBy=sysinit.target
EOT
kconf=$(find /boot -maxdepth 1 -name 'config-*' | sort -V | tail -n 1)
if [ ! -x /usr/sbin/nft ]; then
  echo "--- firewall NOT enabled: nft is not installed (mpkg install nftables)"
elif [ -z "$kconf" ] || ! grep -q '^CONFIG_NF_TABLES=[ym]' "$kconf"; then
  echo "--- firewall NOT enabled: the installed kernel has no nf_tables (rebuild with ch10-kernel.sh)"
else
  systemctl enable nftables
fi
echo "=== DONE hardening"
