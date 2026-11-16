set -e
: "${ROOT_PARTUUID:?ROOT_PARTUUID not set}"
grub-install --target=x86_64-efi --removable --no-nvram --efi-directory=/boot/efi --boot-directory=/boot
mkdir -p /boot/grub
cat > /boot/grub/grub.cfg << EOT
# Begin /boot/grub/grub.cfg
set default=0
set timeout=3

insmod part_gpt
insmod ext2

menuentry "MentholLinux 1.0" {
        search --no-floppy --set=root --label MentholRoot
        linux   /boot/vmlinuz-7.1.8-menthol root=PARTUUID=${ROOT_PARTUUID} ro console=tty0 console=ttyS0,115200
}
EOT
ls -l /boot/efi/EFI/BOOT/
echo "=== DONE ch10-grub"
