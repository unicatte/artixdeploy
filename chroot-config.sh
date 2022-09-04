#!/bin/sh

export FZF_DEFAULT_OPTS="--layout=reverse --height 40%"

. /root/chroot-vars
case $DEST_PART in
	/dev/?d??)
		DEST_DISK=$(printf "%s\n" "$DEST_PART" | sed 's/.$//');;
	/dev/nvme?n?p?)
		DEST_DISK=$(printf "%s\n" "$DEST_PART" | sed 's/..$//');;
esac

DEST_PART_NUM=$(printf "%s\n" "$DEST_PART" | sed 's/\(^.*\)\(.$\)/\2/')

msg() { printf '\033[32m[%s]\033[0m: %s\n' "$this_name" "$1"; }

warning() { printf '\033[33m[%s]\033[0m: %s\n' "$this_name" "$1"; }

error() { printf '\033[31m[%s]\033[0m: %s\n' "$this_name" "$1"; exit 1; }

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
	efibootmgr --disk "$DEST_DISK" --part $DEST_PART_NUM --create --label "Artix Linux" --loader /vmlinuz-linux-zen --unicode "root=PARTUUID=$DEST_ROOT_PARTUUID rw initrc=\\intel-ucode.img initrd=\\initramfs-linux-zen.img quiet loglevel=3" --verbose
}

svcenable(){
	case $init_sys in
		"systemd")
			systemctl enable $1;;
		"openrc")
			rc-update add $1;;
		"runit")
			ln -s /etc/runit/sv/$1 /etc/runit/runsvdir/default;;
	esac
}

if [ "$distrib_id" = "Artix" ]; then
	#sed -i "/\[lib32\]/,/Include/"'s/^#//' /etc/pacman.conf
	msg "Adding universe repo..."
	printf '
[universe]
Server = https://universe.artixlinux.org/$arch
Server = https://mirror1.artixlinux.org/universe/$arch
Server = https://mirror.pascalpuffke.de/artix-universe/$arch
Server = https://artixlinux.qontinuum.space/artixlinux/universe/os/$arch
Server = https://mirror1.cl.netactuate.com/artix/universe/$arch
Server = https://ftp.crifo.org/artix-universe/' >> /etc/pacman.conf
	pacman -Sy --needed --noconfirm artix-archlinux-support archlinux-mirrorlist
	msg "Adding Arch repos..."
	printf '
# ARCH
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[community]
Include = /etc/pacman.d/mirrorlist-arch

#[multilib]
#Include = /etc/pacman.d/mirrorlist-arch\n' >> /etc/pacman.conf

	pacman -Sy
fi

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
[ $init_sys = openrc ] && printf "hostname='%s'" "$HOSTNAME" > /etc/conf.d/hostname

UCODE=( $(dialog --stdout --checklist "Select ucode" 0 0 0 intel-ucode "" off amd-ucode "" off) )
[ -n "${UCODE[@]}" ] && pacman --needed -S ${UCODE[@]}

if [ "$EFI_INSTALL" = true ]
then pacman -S --noconfirm --needed efibootmgr && efistub
else grub
fi

DRIVERS=$(dialog --stdout --checklist "Select graphics drivers" 0 0 0 nvidia-dkms "" off nvidia-utils "" off xf86-video-intel "" off xf86-video-amdgpu "" off xf86-video-ati "" off xf86-video-vesa "" off xf86-video-nouveau "" off xorg-drivers "" off)
[ -n "${DRIVERS[@]}" ] && pacman -S ${DRIVERS[@]}

svcenable NetworkManager

msg "Running LARBS-uni..."
git clone https://github.com/unicatte/LARBS.git
(cd LARBS && sh larbs.sh) || warning "LARBS-uni failed."
rm -rvf LARBS
