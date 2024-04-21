#!/bin/sh

: ${SessionName:="SysUpdate"}
: ${tmuxConfigDir:="${HOME}/bin/sysadmin/params/tmux"}

cd

export tmuxConfigDir
tmuxSession.sh "$SessionName"

