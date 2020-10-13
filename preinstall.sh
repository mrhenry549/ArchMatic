#!/usr/bin/env bash
#-------------------------------------------------------------------------
#      _          _    __  __      _   _
#     /_\  _ _ __| |_ |  \/  |__ _| |_(_)__
#    / _ \| '_/ _| ' \| |\/| / _` |  _| / _|
#   /_/ \_\_| \__|_||_|_|  |_\__,_|\__|_\__|
#  Arch Linux Post Install Setup and Config
#-------------------------------------------------------------------------

echo "-------------------------------------------------"
echo "Setting up mirrors for optimal download - PT Only"
echo "-------------------------------------------------"
timedatectl set-ntp true
pacman -S --noconfirm pacman-contrib reflector
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
reflector --country Portugal --country Spain --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist



echo -e "\nInstalling prereqs...\n$HR"
pacman -S --noconfirm gptfdisk btrfs-progs

echo "-------------------------------------------------"
echo "-------select your disk to format----------------"
echo "-------------------------------------------------"
lsblk
echo "Please enter disk: (example /dev/sda)"
read DISK
echo "--------------------------------------"
echo -e "\nFormatting disk...\n$HR"
echo "--------------------------------------"

# disk prep
sgdisk -Z ${DISK} # zap all on disk
sgdisk -a 2048 -o ${DISK} # new gpt disk 2048 alignment

# create partitions
sgdisk -n 1:0:+1000M ${DISK} # partition 1 (UEFI SYS), default start block, 512MB
sgdisk -n 2:0:0     ${DISK} # partition 2 (Root), default start, remaining

# set partition types
sgdisk -t 1:ef00 ${DISK}
sgdisk -t 2:8300 ${DISK}

# label partitions
sgdisk -c 1:"UEFISYS" ${DISK}
sgdisk -c 2:"ROOT" ${DISK}

# make filesystems
echo -e "\nCreating Filesystems...\n$HR"

mkfs.vfat -F32 -n "UEFISYS" "${DISK}1"
mkfs.ext4 -L "ROOT" "${DISK}2"

# mount target
mkdir /mnt
mount -t ext4 "${DISK}2" /mnt
mkdir /mnt/boot
mkdir /mnt/boot/efi
mount -t vfat "${DISK}1" /mnt/boot/efi

echo "--------------------------------------"
echo "--    Arch Install on Main Drive    --"
echo "--------------------------------------"
pacstrap /mnt base base-devel linux linux-headers linux-lts linux-lts-headers linux-firmware vim nano sudo --noconfirm --needed
genfstab -U /mnt >> /mnt/etc/fstab

echo "--------------------------------------"
echo "-- Bootloader Systemd Installation  --"
echo "--------------------------------------"
arch-chroot /mnt bootctl install
arch-chroot /mnt cat <<EOF > /boot/loader/entries/arch.conf
title Arch Linux  
linux /vmlinuz-linux  
initrd  /initramfs-linux.img  
options root=${DISK}1 rw
EOF

echo "--------------------------------------"
echo "--          Network Setup           --"
echo "--------------------------------------"
arch-chroot /mnt pacman -S networkmanager dhclient --noconfirm --needed
arch-chroot /mnt systemctl enable --now NetworkManager

echo "--------------------------------------"
echo "--         Iniciate ramdisk         --"
echo "--------------------------------------"
arch-chroot /mnt mkinitcpio -p linux
arch-chroot /mnt mkinitcpio -p linux-lts

echo "--------------------------------------"
echo "--      Set Password for Root       --"
echo "--------------------------------------"
echo "Enter password for root user: "
arch-chroot /mnt passwd root

echo "--------------------------------------"
echo "--           Install GRUB           --"
echo "--------------------------------------"
arch-chroot /mnt pacman -S grub efibootmgr dosfstools os-prober mtools --noconfirm --needed
arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
arch-chroot /mnt mkdir /boot/grub/locale
arch-chroot /mnt cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

echo "--------------------------------------"
echo "--     Install Intel microcode      --"
echo "--------------------------------------"
arch-chroot /mnt pacman -S intel-ucode

umount -R /mnt

echo "--------------------------------------"
echo "--   SYSTEM READY FOR FIRST BOOT    --"
echo "--------------------------------------"
