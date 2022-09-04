#!/bin/sh

export FZF_DEFAULT_OPTS="--layout=reverse --height 40%"
EFI_INSTALL=false
init_sys=openrc

msg() { printf '\033[32m[unicatte]\033[0m: %s\n' "$1"; }

warning() { printf '\033[33m[unicatte]\033[0m: %s\n' "$1"; }

error() { printf '\033[31m[unicatte]\033[0m: %s\n' "$1"; exit 1; }

round(){
	RESULT=$(( $2 % $1 ))
	[ $RESULT = 0 ] && printf '%d' $2 && return
	printf '%d' $(( $2 - $RESULT + $1 ))
}

efi(){
	msg "Which partition to use as the EFI system partition?"
	EFI_PART=$( (find /dev/?d?? && find /dev/nvme?n?p?) 2>/dev/null | fzf)
	mkdir -p /mnt/boot
	mount $EFI_PART /mnt/boot
	EFI_INSTALL=true
}

swap(){
	msg "Creating swap file."
	RAM_MB=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))
	dd if=/dev/zero of=/mnt/swapfile bs=1M count="$(round 1024 "$RAM_MB")" status=progress
	chmod 600 /mnt/swapfile
	mkswap -U clear /mnt/swapfile
	swapon /mnt/swapfile
}

. /etc/lsb-release
if ! [ "$DISTRIB_ID" = "Arch" ] && ! [ "$DISTRIB_ID" = "Artix" ]
then error "Operating system not supported. Must be Arch Linux or Artix Linux."
fi
case "$DISTRIB_ID" in
	"Arch")
		sysstrap=pacstrap
		init_sys=systemd
		genfstab=genfstab;;
	"Artix")
		sysstrap=basestrap
		genfstab=fstabgen
		additionalpkg=( $init_sys elogind-$init_sys networkmanager-$init_sys );;
esac

pacman --noconfirm --needed -Sy fzf || error "Error downloading essential install packages."

msg "Please partition and format the drive using your favorite partitioning tool and exit the shell. Do NOT mount partitions before exiting the shell."
sh

msg "Which partition to use as root?"
DEST_PART=$( (find /dev/?d?? && find /dev/nvme?n?p?) 2>/dev/null | fzf)
mount "$DEST_PART" /mnt

[ -d /sys/firmware/efi/efivars/ ] && (efi || error "Failed to configure EFI")
swap || error "Failed to configure swap"

msg "Installing the base system..."
$sysstrap /mnt base base-devel linux-zen linux-zen-headers linux-firmware fzf zsh git neovim networkmanager dialog xdg-user-dirs mesa $additionalpkg || error "Error downloading essential system packages."
$genfstab -U /mnt >> /mnt/etc/fstab
cp chroot-config.sh /mnt/root/
printf 'distrib_id=%s
EFI_INSTALL=%s
DEST_PART=%s
init_sys=%s\n' "$DISTRIB_ID" "$EFI_INSTALL" "$DEST_PART" "$init_sys" > /mnt/root/chroot-vars
artix-chroot /mnt sh /root/chroot-config.sh

rm -v /mnt/root/chroot-config.sh /mnt/root/chroot-vars
swapoff /mnt/swapfile
[ $EFI_INSTALL = true ] && umount /mnt/boot
umount /mnt

msg "Installation finished! Reboot in order to use your newly installed operating system!"
