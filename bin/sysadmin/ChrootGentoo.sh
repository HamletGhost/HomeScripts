#!/bin/sh

: ${RootDev:=${1:-/dev/sda6}}
: ${RootDir:="/mnt/gentoo"}

SCRIPTDIR="$(dirname "$0")"

cd /
mount "$RootDev" "$RootDir"
cd "$RootDir"
rm -f "${RootDev}/etc/mtab"
mount -t proc proc proc
mount -t sysfs sys sys
mount -o bind /dev dev

# first chroot, only to mount everything else
echo "Activating LVM volumes..."
vgscan
vgchange -a y
echo "Mounting file systems..."
chroot . mount -a

# real change root
echo "Changing to new root in '${RootDev}'"
chroot .
echo "Back to the previous root."

