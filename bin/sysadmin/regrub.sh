#!/usr/bin/env bash

declare GrubTarget='x86_64-efi'

function remount() {
  Options="$1"
  shift
  MountPoints=( "$@" )
  local MountPoint
  for MountPoint in "${MountPoints[@]}" ; do
    mount -o remount,${Options} "$MountPoint"
  done
} # remount()


remount rw /boot /boot/EFI

for BootDrive in '/dev/sdb' '/dev/nvme0n1p1' ; do
    echo "Running grub-install on '${BootDrive}':"
    Cmd=( grub-install ${VERBOSE:+"--verbose"} --target="$GrubTarget" "$BootDrive" )
    echo "${Cmd[@]}"
    "${Cmd[@]}" || exit $?
done

remount ro /boot /boot/EFI
