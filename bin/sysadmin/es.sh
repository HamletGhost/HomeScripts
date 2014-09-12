#!/bin/sh

: ${SessionName:="SysUpdate"}
: ${tmuxConfigDir:="${HOME}/bin/sysadmin/params/tmux"}

cd
mount /usr/portage
umount ~ftp/repository/gentoo-portage
mount ~ftp/repository/gentoo-portage

export tmuxConfigDir
tmuxSession.sh "$SessionName"

