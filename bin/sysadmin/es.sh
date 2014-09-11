#!/bin/sh

: ${SessionName:="SysUpdate"}

# first wipe screens which are dead (but ignore the output completely):
screen -wipe >& /dev/null

# sadly, the temporary file will be left around, since otherwise screen will
# not be able to reattach a detached session.

# try to recover an existing one, if any
screen -rd "$SessionName" && exit


# TMPFILE="$(mktemp)"
TMPFILE="${TMPDIR:="/tmp"}/${USER}/es-screen.conf"

cd
mount /usr/portage
umount ~ftp/repository/gentoo-portage
mount ~ftp/repository/gentoo-portage

echo "Temporary file: '${TMPFILE}'"

mkdir -p "$(dirname "$TMPFILE")"
cat <<EOF > "$TMPFILE"
sessionname ${SessionName}
screen -t pretend
screen -t emerge
screen -t fetch
EOF

screen -c "$TMPFILE"

# rm -f "$TMPFILE"

