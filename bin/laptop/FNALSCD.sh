#!/bin/bash
#
# Mounts the FNAL disk
#

function LASTFATAL() {
	local Code=$?
	[[ $Code == 0 ]] && return 0
	echo "FATAL ERROR (${Code}): $*"
	exit $Code
} # LASTFATAL()

VolumeGroup="FNAL_SCS_124099"
MountPoint="/mnt/FNALdata"

Device="$(readlink -f "/dev/disk/by-id/dev/disk/by-id/ata-WDC_WD40EZRX-00SPEB0_WD-WCC4E0500885")"
: ${Device:="/dev/sdb"}

case "$1" in
	( --umount | -u | umount | unmount )
		sudo /usr/local/bin/UmountDrive.sh "${Device#/dev/}"
		;;
	
	( --mount | -m | mount )
		
		sudo /usr/local/bin/ActivateDrive.sh "${Device#/dev/}"
		
		echo "Mounting '${MountPoint}'"
		mount "$MountPoint"
		LASTFATAL "Failed to mount '${MountPoint}'"
		
		echo "FNAL external disk mounted."
		;;
	( * )
		echo "Please specify whether to mount or unmount the disk."
		exit 1
		;;
esac
