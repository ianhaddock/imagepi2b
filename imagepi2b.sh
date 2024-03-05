#!/bin/bash -e

#
# Ian Haddock April 23, 2023
# Provided “AS IS” and without warranty of any kind.
#


function usage() 
{
    echo "      .~~.   .~~.      ";
    echo "     '. \ ' ' / .'     ";
    echo "      .~ .~~~..~.      ";
    echo "     : .~.'~'.~. :     ";
    echo "    ~ (   ) (   ) ~    ";
    echo "   ( : '~'.~.'~' : )   ";
    echo "    ~ .~ (   ) ~. ~    ";
    echo "     (  : '~' :  )i    ";
    echo "      '~ .~~~. ~'      ";
    echo "          '~'          ";
    echo "";
    echo "# # # # WARNING # # # #";
    echo "This script: "
    echo "* downloads and writes a 32bit Raspberry Pi OS Lite image to your MicroSD";
    echo "* creates the root partition on a 64G USB device with these partitions:";
    echo "  /home, /tmp, /mnt, /var, /var/log, /var/tmp";
    echo "";
    echo "By continuing you understand this will DESTRUCTIVELY modify the device.";
    echo "This Software is provided “AS IS” and without warranty of any kind.";
    echo "";
    echo "Usage: imagepi2b.sh [boot MicroSD] [root USB]";
    echo "";
};


# sanity check arguments
if [ ! $# == 2 ]; then
	usage;
	exit 1;
fi;

# sanity check user
if [ ! $(id -u) = 0 ]; then  
    usage;
    echo "Error: This script needs to run as root to image the drives.";
    exit 1;
fi

# sanity check inputs
if [ ! -b "$1" ] || [ ! -b "$2" ]; then
    usage;
    exit 1;
else
    SD="$1"
    USB="$2"
fi


# confirm with user
usage;
echo "Here is what will happen:";
echo "* Create the boot partition on: $SD";
echo "* Create the root partition on: $USB";
echo "";
echo "Continue? <y/n>";
read answer; 
if [ "$answer" != 'y' ]; then
	echo "aborting."
	exit 1;
fi;


# image MicroSD
TMPFILE="$BASHPID-tmp"
IMAGE="/tmp/$TMPFILE/raspios_lite.img.xz"

# pull 32bit image
if [ ! -d /tmp/"$TMPFILE" ]; then
        mkdir /tmp/"$TMPFILE";
        echo "Downloading Raspberry Pi 32bit image.";
        wget --no-clobber -O "$IMAGE" \
        'https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2023-05-03/2023-05-03-raspios-bullseye-armhf-lite.img.xz'
fi

echo "uncompress and image microSD";
if [ "${IMAGE##*.}" = xz ]; then
    xz --stdout -d "$IMAGE" | dd of="$SD" bs=1024M
fi
if [ "${IMAGE##*.}" = zip ]; then
    unzip -p "$IMAGE" | dd of="$SD" bs=1024M
fi

echo "cleanup temp file";
rm -rf /tmp/"$TMPFILE";


# setup USB
echo "build USB partitions";
/sbin/parted --script $USB \
	mklabel msdos \
	mkpart primary ext4 1 15GB \
	mkpart extended 15GB 60GB \
	mkpart logical ext4 15GB 25GB \
	mkpart logical ext4 25GB 30GB \
	mkpart logical ext4 30GB 35GB \
	mkpart logical ext4 35GB 40GB \
    mkpart logical ext4 40GB 45GB \
	mkpart logical ext4 45GB 46GB \
	mkpart logical ext4 46GB 60GB ;

echo "create USB file systems";
mkfs.ext4 -Fq "$USB"1
mkfs.ext4 -Fq "$USB"5
mkfs.ext4 -Fq "$USB"6
mkfs.ext4 -Fq "$USB"7
mkfs.ext4 -Fq "$USB"8
mkfs.ext4 -Fq "$USB"9
mkfs.ext4 -Fq "$USB"10
mkfs.ext4 -Fq "$USB"11

echo "add rootfs label to first partition";
e2label "$USB"1 "rootfs";


# copy files
echo "creating working directories at /mnt/rpi";
mkdir -p /mnt/rpi/{sd,sdboot,usb,tmp,var/tmp,var/log,home,mnt}

echo "mount microSD media";
mount "$SD"1  /mnt/rpi/sdboot;
mount "$SD"2  /mnt/rpi/sd;

echo "mount USB mountpoints";
mount "$USB"1  	/mnt/rpi/usb
mount "$USB"5 	/mnt/rpi/home
mount "$USB"6 	/mnt/rpi/tmp
mount "$USB"7 	/mnt/rpi/var
mount "$USB"10 	/mnt/rpi/mnt

echo "sync root files";
rsync -a --delete \
	--exclude '/mnt/rpi/sd/home' \
       	--exclude '/mnt/rpi/sd/tmp' \
	--exclude '/mnt/rpi/sd/var' \
	--exclude '/mnt/rpi/sd/mnt' \
	/mnt/rpi/sd/ \
	/mnt/rpi/usb ;

echo "sync home files";
rsync -a --delete /mnt/rpi/sd/home/  		/mnt/rpi/home

echo "sync tmp files";
rsync -a --delete /mnt/rpi/sd/tmp/  		/mnt/rpi/tmp

echo "sync var files";
rsync -a --delete \
	--exclude '/mnt/rpi/sd/var/tmp' \
	--exclude '/mnt/rpi/sd/var/log' \
	/mnt/rpi/sd/var/ \
	/mnt/rpi/var ;

echo "sync mnt files";
rsync -a --delete /mnt/rpi/sd/mnt/   		/mnt/rpi/mnt

echo "mount var/temp and var/log";
mount "$USB"8 	/mnt/rpi/var/tmp
mount "$USB"9 	/mnt/rpi/var/log

echo "sync var/tmp files";
rsync -a --delete /mnt/rpi/sd/var/tmp/  	/mnt/rpi/var/tmp

echo "sync var/log files";
rsync -a --delete /mnt/rpi/sd/var/log/  	/mnt/rpi/var/log


# setup for boot
echo "add new root device to cmdline.txt";
cp /mnt/rpi/sdboot/cmdline.txt /mnt/rpi/sdboot/cmdline.txt-bak
rootuuid=$(blkid | grep "$USB"1: | awk '{print $5}' | cut -c 11-21);
sed -i "s/PARTUUID=........... rootfstype/PARTUUID=$rootuuid rootfstype/" /mnt/rpi/sdboot/cmdline.txt ;

echo "add new root partitions to fstab";
cp /mnt/rpi/usb/etc/fstab /mnt/rpi/usb/etc/fstab-bak ;

uuid=$(blkid | grep "$USB"1: | awk '{print $5}' | cut -c 11-21);
sed -i "s/PARTUUID=...........  \/ /PARTUUID=$uuid  \/ /" /mnt/rpi/usb/etc/fstab ;

echo "" >> /mnt/rpi/usb/etc/fstab

uuid=$(blkid | grep "$USB"5: | awk '{print $4}' | cut -c 11-21);
echo "PARTUUID=$uuid	/home		ext4	rw,nodev		0	2" >> /mnt/rpi/usb/etc/fstab ;

uuid=$(blkid | grep "$USB"6: | awk '{print $4}' | cut -c 11-21);
echo "PARTUUID=$uuid	/tmp		ext4	rw,nodev		0	2" >> /mnt/rpi/usb/etc/fstab ;

uuid=$(blkid | grep "$USB"7: | awk '{print $4}' | cut -c 11-21);
echo "PARTUUID=$uuid	/var		ext4	defaults		0	2" >> /mnt/rpi/usb/etc/fstab ;

uuid=$(blkid | grep "$USB"8: | awk '{print $4}' | cut -c 11-21);
echo "PARTUUID=$uuid	/var/tmp	ext4	rw,noexec,nodev		0	2" >> /mnt/rpi/usb/etc/fstab ;

uuid=$(blkid | grep "$USB"9: | awk '{print $4}' | cut -c 11-21);
echo "PARTUUID=$uuid	/var/log	ext4	rw,noexec,nodev		0	2" >> /mnt/rpi/usb/etc/fstab ;

uuid=$(blkid | grep "$USB"10: | awk '{print $4}' | cut -c 11-21);
echo "PARTUUID=$uuid	/mnt		ext4	rw,noexec,nodev		0	2" >> /mnt/rpi/usb/etc/fstab ;

uuid=$(blkid | grep "$USB"11: | awk '{print $4}' | cut -c 11-21);
echo "PARTUUID=$uuid	/mnt/containers		ext4	rw,nodev	0	2" >> /mnt/rpi/usb/etc/fstab ;


# create containers directory on USB media target
mkdir /mnt/rpi/usb/mnt/containers


# cleanup 
echo "entries changed:";
echo "";
echo "cmdline.txt:";
cat /mnt/rpi/sdboot/cmdline.txt;
echo "";
echo "fstab:";
cat /mnt/rpi/usb/etc/fstab;
echo "";

echo "unmount /mnt/rpi working directories";
umount -lq /mnt/rpi/*

echo "cleanup /mnt/rpi directories";
rm -rf /mnt/rpi

echo "script completed in:"; 
times; 


exit 0;
