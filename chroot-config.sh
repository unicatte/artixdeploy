#!/bin/sh

export FZF_DEFAULT_OPTS="--layout=reverse --height 40%"

. /root/chroot-vars
DEST_DISK=$(printf "%s\n" "$DEST_PART" | sed 's/.$//')
DEST_PART_NUM=$(printf "%s\n" "$DEST_PART" | sed 's/\(^.*\)\(.$\)/\2/')

msg() { printf '\033[32m[unicatte]\033[0m: %s\n' "$1"; }

error() { printf '\033[31m[unicatte]\033[0m: %s\n' "$1"; exit 1; }

grub(){
	msg "Installing GRUB."
	pacman -S --needed grub os-prober
	grub-install --target=i386-pc "$DEST_DISK"
	grub-mkconfig -o /boot/grub/grub.cfg
	msg "GRUB Installed."
}

efistub(){
	DEST_ROOT_PARTUUID=$(find /dev/disk/by-partuuid/ -lname ../../"$(printf '%s' "$DEST_PART" | sed 's:.*/::')" | sed 's:.*/::')
	msg "Adding EFI entry."
	efibootmgr --disk "$DEST_DISK" --part "$DEST_PART_NUM" --create --label "Artix Linux" --loader /vmlinuz-linux-zen --unicode "root=PARTUUID=$DEST_ROOT_PARTUUID rw initrd=\initramfs-linux-zen.img quiet loglevel=3" --verbose
}

msg "Adding Arch repos..."
#sed -i "/\[lib32\]/,/Include/"'s/^#//' /etc/pacman.conf
printf '
# ARCH
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[community]
Include = /etc/pacman.d/mirrorlist-arch

#[multilib]
#Include = /etc/pacman.d/mirrorlist-arch\n' >> /etc/pacman.conf

pacman -Sy

msg "Please enter the city of your timezone and select from the list."
ln -sf "$(find /usr/share/zoneinfo/*/ -maxdepth 1 -type f | fzf)" /etc/localtime
hwclock --systohc

msg "You will now edit the locale file and uncomment your chosen locale options. Please press [ENTER]."
read -rn 1
nvim /etc/locale.gen
locale-gen

# TO REMOVE after locking the root user has become a part of the script.
msg "Entering the root password..."
passwd

msg "Please enter your preferred hostname."
read -r HOSTNAME
printf '%s\n' "$HOSTNAME" > /etc/hostname
printf '127.0.0.1	localhost
::1		localhost
127.0.1.1	%s.localdomain	%s\n' "$HOSTNAME" "$HOSTNAME" >> /etc/hosts

UCODE=$(dialog --stdout --checklist "Select ucode" 0 0 0 intel-ucode "" off amd-ucode "" off)
[ "$UCODE" = "" ] || pacman -S $UCODE

if [ "$EFI_INSTALL" = true ]
then pacman -S --noconfirm --needed efibootmgr && efistub
else grub
fi

DRIVERS=$(dialog --stdout --checklist "Select graphics drivers" 0 0 0 nvidia "" off nvidia-utils "" off xf86-video-intel "" off xf86-video-amdgpu "" off xf86-video-ati "" off xf86-video-vesa "" off xf86-video-nouveau "" off xorg-drivers "" off)
[ "$DRIVERS" = "" ] || pacman -S $DRIVERS

ln -s /etc/runit/sv/NetworkManager /etc/runit/runsvdir/default/

msg "Running LARBS-uni..."
git clone https://github.com/unicatte/LARBS.git
(cd LARBS && sh larbs.sh) || error "LARBS-uni failed."
