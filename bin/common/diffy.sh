#!/bin/sh

SCRIPTNAME="$(basename "$0")"
SCRIPTDIR="$(dirname "$0")"

: ${WIDTH:="$(sed -e 's/^diffy\([0-9]*\).sh$/\1/' <<< "$SCRIPTNAME" )"}

[[ "$WIDTH" == "$SCRIPTNAME" ]] && WIDTH=""
if [[ -z "$WIDTH" ]];
	[[ -z "$COLUMNS" ]] && eval $(resize)
	WIDTH="$COLUMNS"
fi

diff -y ${WIDTH:+-W "${WIDTH}"} -b "$@" | less -SRMr -x 8


