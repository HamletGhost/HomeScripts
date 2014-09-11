#!/bin/sh

function isFlagSet() {
	local VarName="$1"
	[[ -n "${!VarName//0}" ]]
}


function ERROR() {
	echo "$*" >&2
}

function FATAL() {
	local Code="$1"
	shift
	ERROR "$*"
	exit $Code
}


CONFIGFILE="$1"
: ${CONFIGFILE:="/usr/src/linux/.config"}

[[ -r "$CONFIGFILE" ]] || FATAL 2 "Can't open config file '${CONFIGFILE}'."

FILTERSETS="-e s/=.*//"
FILTERCMD1="cat"
isFlagSet NOSET && FILTERCOMMAND="$FILTERSETS"


echo "# Config file: '${CONFIGFILE}'"
grep 'CONFIG_' "$CONFIGFILE" | sed -e 's/# CONFIG_/CONFIG_/' -e 's/^CONFIG_//' -e 's/ is not set.*/=n/' $FILTERCOMMAND | grep -v '^#' | sort

