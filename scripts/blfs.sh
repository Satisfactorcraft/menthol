. /lfs-scripts/ch8-lib.sh
# CA bundle (copied from the build host by the caller into /lfs-scripts/ca-bundle.pem)
install -d /etc/ssl/certs
install -m644 /lfs-scripts/ca-bundle.pem /etc/ssl/certs/ca-certificates.crt
ln -sfv ca-certificates.crt /etc/ssl/certs/ca-bundle.crt

unpack curl-8.21.0.tar.xz
./configure --prefix=/usr --disable-static --with-openssl --without-libpsl --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt
make && make install
done_pkg

unpack wget-1.25.0.tar.gz
NEW_LINE='#if !defined OPENSSL_NO_SSL3_METHOD '
NEW_LINE+='&& OPENSSL_VERSION_NUMBER < 0x40000000L'
sed -i "/SSL3/c $NEW_LINE" src/openssl.c
./configure --prefix=/usr --sysconfdir=/etc --with-ssl=openssl --without-libpsl
make && make install
echo "ca_certificate=/etc/ssl/certs/ca-certificates.crt" >> /etc/wgetrc
done_pkg

unpack sudo-1.9.17p2.tar.gz
sed -e 's/\([->.a-zA-Z_]*\)->length/ASN1_STRING_length(\1)/' -i lib/iolog/hostcheck.c
./configure --prefix=/usr --libexecdir=/usr/lib --with-secure-path --with-env-editor --without-pam --docdir=/usr/share/doc/sudo-1.9.17p2 --with-passprompt="[sudo] password for %p: "
make && make install
install -dm755 /etc/sudoers.d
cat > /etc/sudoers.d/00-sudo << "EOT"
Defaults secure_path="/usr/sbin:/usr/bin"
%wheel ALL=(ALL) ALL
EOT
chmod 440 /etc/sudoers.d/00-sudo
done_pkg

unpack openssh-10.5p1.tar.gz
install -v -g sys -m700 -d /var/lib/sshd
getent group sshd >/dev/null || groupadd -g 50 sshd
id sshd >/dev/null 2>&1 || useradd -c 'sshd PrivSep' -d /var/lib/sshd -g sshd -s /bin/false -u 50 sshd
./configure --prefix=/usr --sysconfdir=/etc/ssh --with-privsep-path=/var/lib/sshd --with-default-path=/usr/bin --with-superuser-path=/usr/sbin:/usr/bin --with-pid-dir=/run
make && make install
install -v -m755 contrib/ssh-copy-id /usr/bin
install -v -m644 contrib/ssh-copy-id.1 /usr/share/man/man1
install -v -m755 -d /usr/share/doc/openssh-10.5p1
install -v -m644 INSTALL LICENCE OVERVIEW README* /usr/share/doc/openssh-10.5p1
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
done_pkg
cat > /usr/lib/systemd/system/sshd.service << "EOT"
[Unit]
Description=OpenSSH server daemon
After=network.target

[Service]
ExecStartPre=/usr/bin/ssh-keygen -A
ExecStart=/usr/sbin/sshd -D
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOT
systemctl enable sshd

unpack git-2.55.0.tar.xz
./configure --prefix=/usr --with-gitconfig=/etc/gitconfig --with-python=python3 --with-libpcre2
make NO_RUST=1
make NO_RUST=1 perllibdir=/usr/lib/perl5/5.44/site_perl install
done_pkg
echo "=== DONE blfs"
