#!/bin/sh
#
# Usage:  PortageFTPserver.sh [Start|Stop]
#

SCRIPTNAME="$(basename "$0")"

PORTAGEDIR="/usr/portage"
PORTAGEDISTFILE="${PORTAGEDIR}/distfiles"

function STDERR() {
	echo "$*" >&2
} # STDERR()

function ERROR() {
	STDERR "${SCRIPTNAME} - Error: $*"
} # ERROR()

function LASTERROR() {
	local res="$?"
	[[ $res == 0 ]] && return 0
	STDERR "${SCRIPTNAME} - Error (${res}): $*"
	return $res
} # LASTERROR()

function FATAL() {
	local Code="$1"
	shift
	STDERR "${SCRIPTNAME} - Fatal error (${Code}): $*"
	exit $Code
} # FATAL()

function LASTFATAL() {
	local res="$?"
	[[ "$res" != 0 ]] && FATAL "$res" "$@"
} # LASTFATAL()


###############################################################################
function Start() {

	# mount the portage distfile directory
	if [[ -r "${PORTAGEDIR%%/}/Unmounted." ]]; then
		mount "$PORTAGEDIR"
		LASTFATAL "Can't mount portage directory ('${PORTAGEDIR}')."
	fi

	# mount the portage distfile directory
	if [[ -r "${PORTAGEDISTFILE%%/}/Unmounted." ]]; then
		mount "$PORTAGEDISTFILE"
		LASTFATAL "Can't mount portage distfile directory ('${PORTAGEDISTFILE}')."
	fi

	# start the rsync server
	if ! rc-service rsyncd status >& /dev/null ; then
		rc-service rsyncd start
		LASTFATAL "Can't start rsync server."
	fi
	
	# start the AutoFS server
	if ! rc-service autofs status >& /dev/null ; then
		rc-service autofs start
		LASTFATAL "Can't start autofs server."
	fi


	# start the FTP server 
	if ! rc-service proftpd status >& /dev/null ; then
		rc-service proftpd start
		LASTFATAL "Can't start FTP server."
	fi
	
	return 0
} # Start()


function Stop() {
	local res

	# stop the FTP server
	if rc-service proftpd status >& /dev/null ; then
		rc-service proftpd stop
		LASTERROR "Can't stop FTP server."
	fi

	# stop the rsync server
	if rc-service rsyncd status >& /dev/null ; then
		rc-service rsyncd stop
		LASTERROR "Can't stop rsync server."
	fi

	return 0
} # Stop()


###############################################################################
Action="$1"
case "${Action,,}" in
	( "start" )
		Start
		;;
	( "stop" )
		Stop
		;;
	( * )
		FATAL 1 "${SCRIPTNAME}: action '${Action}' not supported!"
		;;
esac

