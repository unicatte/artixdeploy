#!/bin/sh

export FZF_DEFAULT_OPTS="--layout=reverse --height 40%"

msg() { printf '\033[32m[unicatte]\033[0m: %s\n' "$1"; }

error() { printf '\033[31m[unicatte]\033[0m: %s\n' "$1"; exit 1; }

round(){
	RESULT=$(( "$2" % "$1" ))
	[ "$RESULT" = 0 ] && printf '%d' "$2" && return
	printf '%d' "$(( "$2" - "$RESULT" + "$1" ))"
}

efi(){
	msg "Do you need an EFI system partition? (Y/n)"
	read -r DEPLOY_CHOICE
	[ "$DEPLOY_CHOICE" = "n" ] || [ "$DEPLOY_CHOICE" = "N" ] && return
	msg "Which partition to use as the EFI system partition?"
	EFI_PART=$(find /dev/sd?? | fzf)
	mount "$EFI_PART" /mnt/boot
	EFI_INSTALL=true
}

swap(){	
	msg "Creating swap file."
	RAM_MB=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))
	dd if=/dev/zero of=/mnt/swapfile bs=1M count="$(round 1024 "$RAM_MB")" status=progress
	chmod 600 /mnt/swapfile
	mkswap /mnt/swapfile
	swapon /mnt/swapfile
}

. /etc/lsb-release
[ "$DISTRIB_ID" = "Artix" ] || error "Not running Artix."

pacman --noconfirm --needed -Sy fzf || error "Error downloading essential install packages."

msg "Please partition and format the drive using your favorite partitioning tool and exit the shell. Do NOT mount partitions before exiting the shell."
sh

msg "Which partition to use as root?"
DEST_PART=$(find /dev/sd?? | fzf)
mount "$DEST_PART" /mnt

efi || error "Failed to configure EFI"
swap || error "Failed to configure swap"

msg "Installing the base system..."
basestrap /mnt base base-devel linux-zen linux-zen-headers linux-firmware runit elogind-runit fzf zsh git neovim networkmanager networkmanager-runit dialog xdg-user-dirs artix-archlinux-support mesa || error "Error downloading essential system packages."
fstabgen -U /mnt >> /mnt/etc/fstab
cp chroot-config.sh /mnt/root/
printf 'EFI_INSTALL=%s
DEST_PART=%s\n' "$EFI_INSTALL" "$DEST_PART" > /mnt/root/chroot-vars
artix-chroot /mnt sh /root/chroot-config.sh

rm -v /mnt/root/chroot-config.sh /mnt/root/chroot-vars
swapoff /mnt/swapfile
[ "$EFI_INSTALL" = "true" ] && umount /mnt/boot
umount /mnt

msg "Installation finished! Reboot in order to use your newly installed operating system!"
