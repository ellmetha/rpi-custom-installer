#!/bin/bash
# A script to prepare and install a Raspbian system on a SD Card.
#
# ellmetha
# Distributed under the GPL version 3 license
#
VERSION="1.1"
INIT_DIR=$PWD


# Debootstrap params
#--------------------------------------------------------------------------------
MIRROR="http://archive.raspbian.org/raspbian"
ARCH="armhf"
SUITE="wheezy"

# SD card params
#--------------------------------------------------------------------------------
BOOTP_SIZE="64M"
BUILDENV="/mnt/rootfs--"`date +%Y%m%d`

# System params
#--------------------------------------------------------------------------------
ROOT_PASSWD="toor"

DEB_MIRROR="http://mirrordirector.raspbian.org/raspbian"
APT_SOURCES="deb ${DEB_MIRROR} ${SUITE} main contrib non-free rpi firmware
deb-src ${DEB_MIRROR} ${SUITE} main contrib non-free rpi firmware"
PACKAGES="vim"

HOSTNAME_RPI="rpi"
TIMEZONE="Europe/Paris"
LOCALES="fr_FR.UTF-8 UTF-8"
KEYBOARD_CONFIGURATION="fr"

FSTAB="proc	/proc 	proc 	defaults        0       0
/dev/mmcblk0p1	/boot 	vfat    defaults        0       0"

NETWORKING="auto lo
iface lo inet loopback
auto eth0
iface eth0 inet dhcp"

# Third stage
#--------------------------------------------------------------------------------
THIRD_STAGE="#!/bin/bash
apt-get update
# Configure locales
echo ${LOCALES} >> /etc/locale.gen
# Install packages
DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install libraspberrypi0 libraspberrypi-dev libraspberrypi-bin raspberrypi-bootloader-nokernel
DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install linux-image-3.6-trunk-rpi
DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install git-core binutils ca-certificates locales ntpdate console-setup keyboard-configuration sudo make
DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install openssh-server ssh-regen-startup
DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install ${PACKAGES}
DEBIAN_FRONTEND=noninteractive apt-get clean
rm /etc/ssh/ssh_host_*
# Configure timezone
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
# Configure keyboard
sed -i 's/XKBLAYOUT=\"us\"/XKBLAYOUT=\"${KEYBOARD_CONFIGURATION}\"/g' /etc/default/keyboard
# Set root password
echo -e \"${ROOT_PASSWD}\n${ROOT_PASSWD}\" | passwd root
# Prepare boot configuration
echo '# Set params for \"raspbian debian-style kernel\" boot' >> /boot/config.txt
echo 'kernel=vmlinuz-3.6-trunk-rpi' >> /boot/config.txt
echo 'initramfs initrd.img-3.6-trunk-rpi followkernel' >> /boot/config.txt
# Final operations
rm /usr/bin/qemu-arm-static
"


# ~STEP1: Verifications & preparation
#--------------------------------------------------------------------------------

# The script must be run as root
if [ $EUID -ne 0 ]; then
	echo "This tool must be run as root: # sudo $0" 1>&2
	exit 1
fi

# The targetted device must be a block device
target_device=$1
if ! [ -b $target_device ]; then
	echo "$target_device is not a block device"
	exit 1
elif [ -z $target_device ]; then
	echo "A block device must be specified"
	exit 1
fi

# For safety, wait for user confirmation before process install
echo
echo -e "\033[32m   .~~.   .~~.\033[0m"
echo -e "\033[32m  '. \ ' ' / .'\033[0m"
echo -e "\033[31m   .~ .~~~..~.\033[0m"
echo -e "\033[31m  : .~.'~'.~. :\033[0m     The system will be installed on:"
echo -e "\033[31m ~ (   ) (   ) ~\033[0m          $target_device"
echo -e "\033[31m( : '~'.~.'~' : )\033[0m"
echo -e "\033[31m ~ .~ (   ) ~. ~\033[0m    Sure? Then, press [Enter]"
echo -e "\033[31m  (  : '~' :  )\033[0m"
echo -e "\033[31m   '~ .~~~. ~'\033[0m"
echo -n -e "\033[31m       '~'          \033[0m"
read
echo


# ~STEP2: Prepare SD Card and create the required filesystems
#--------------------------------------------------------------------------------

# Delete MBR & partition table from the SD card
dd if=/dev/zero of=$target_device bs=512 count=1

# Create the required partitions
fdisk $target_device << EOF
n
p
1

+$BOOTP_SIZE
t
c
n
p
2


w
EOF

# Verify that the partition has been created
if ! [ -b ${target_device}1 && -b ${target_device}2 ]; then
	echo "The required partitions do not seem to have been created"
	exit 1
else
	bootp=${target_device}1
	rootp=${target_device}2
fi

# Partitions formatting
mkfs.vfat $bootp
mkfs.ext4 $rootp

# Mounting root partition
mkdir $BUILDENV
mount $rootp $BUILDENV


# ~STEP3: Installation & configuration
#--------------------------------------------------------------------------------

# Debootstrap the system
cd $BUILDENV
debootstrap --foreign --arch armhf $SUITE $BUILDENV $MIRROR

# Copy qemu-arm-static to the build directory to be able to run ARM binaries
cp $(which qemu-arm-static) usr/bin

# Chroot to the build directory and finalize the debootstrap process
LC_ALL="C" chroot $BUILDENV /debootstrap/debootstrap --second-stage

# Mount the boot partition
mount $bootp ${BUILDENV}/boot

# Fill /etc/apt/sources.list
echo "$APT_SOURCES" > etc/apt/sources.list

# Fill /etc/fstab
echo "$FSTAB" > etc/fstab

# Fill /etc/hostname
echo "$HOSTNAME_RPI" > etc/hostname

# Fill /etc/network/interfaces
echo "$NETWORKING" > etc/network/interfaces

# Exec third-stage
echo "$THIRD_STAGE" > third-stage
chmod +x third-stage
LC_ALL="C" chroot $BUILDENV /third-stage


# ~STEP4: This is the end
#--------------------------------------------------------------------------------

# Goto initial dir and umount root partition and boot partition
cd $INIT_DIR
umount ${BUILDENV}/boot
umount ${BUILDENV}

echo "Done."

