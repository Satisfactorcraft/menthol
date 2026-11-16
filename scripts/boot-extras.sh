set -e
: "${ROOT_PARTUUID:?ROOT_PARTUUID not set}"
: "${LOOPDEV:?LOOPDEV not set}"
# UEFI (removable path, no NVRAM writes) and legacy BIOS (needs a bios_grub partition on the GPT disk)
grub-install --target=x86_64-efi --removable --no-nvram --efi-directory=/boot/efi --boot-directory=/boot
grub-install --target=i386-pc --boot-directory=/boot $LOOPDEV
mkdir -p /boot/grub
cat > /boot/grub/grub.cfg << EOT
# Begin /boot/grub/grub.cfg (MentholLinux)
set default=0
set timeout=5
set color_normal=light-cyan/black
set color_highlight=black/light-cyan
set menu_color_normal=light-cyan/black
set menu_color_highlight=black/light-cyan

insmod part_gpt
insmod ext2
insmod search_label

menuentry "MentholLinux 1.0" {
        search --no-floppy --set=root --label MentholRoot
        linux   /boot/vmlinuz-7.1.8-menthol root=PARTUUID=${ROOT_PARTUUID} ro console=tty0 console=ttyS0,115200
}

menuentry "MentholLinux 1.0 (recovery shell)" {
        search --no-floppy --set=root --label MentholRoot
        linux   /boot/vmlinuz-7.1.8-menthol root=PARTUUID=${ROOT_PARTUUID} ro console=tty0 console=ttyS0,115200 systemd.unit=rescue.target
}

menuentry "MentholLinux 1.0 (verbose boot)" {
        search --no-floppy --set=root --label MentholRoot
        linux   /boot/vmlinuz-7.1.8-menthol root=PARTUUID=${ROOT_PARTUUID} ro console=tty0 console=ttyS0,115200 loglevel=7 systemd.show_status=true
}
# End /boot/grub/grub.cfg
EOT
echo "=== DONE boot-extras"
