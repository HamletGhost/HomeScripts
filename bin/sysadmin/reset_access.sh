#!/bin/sh
#

if [ -n "$1" ]; then
	cat <<EOH

Restores the correct settings allowing:
- a user in shutdown group to turn machine off
	
EOH
	exit
fi

SBINPROGS="shutdown halt reboot poweroff "
USRSBINPROGS="hibernate* "
GROUP="shutdown"
SBINGROUP=`echo "$SBINPROGS" | sed -e 's@\([^ ]*\)\s@/sbin/\1 @g'`
USRSBINGROUP=`echo "$USRSBINPROGS" | sed -e 's@\([^ ]*\)\s@/usr/sbin/\1 @g'`
LINKGROUP=`echo "$LINKPROGS" | sed -e 's@\([^ ]*\)\s@../sbin/\1 @g'`

echo "Changing $SBINGROUP $USRSBINGROUP"
for f in $SBINGROUP ; do
	[[ -r "$f" ]] && chgrp $GROUP $f
done
for f in $SBINGROUP $USRBINGROUP ; do
	[[ -r "$f" ]] || continue
	chmod 754 $f
	chmod +s $f
done
ln -sf $SBINGROUP /bin
ln -sf $USRSBINGROUP /usr/bin

