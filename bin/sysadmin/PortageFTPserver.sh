#!/bin/sh
#
# Usage:  PortageFTPserver.sh [Start|Stop]
#

SCRIPTNAME="$(basename "$0")"

PORTAGEDIR="/usr/portage"
PORTAGEDISTFILE="${PORTAGEDIR}/distfiles"
FTPDISTFILE="/home/ftp/repository/gentoo-portage/distfiles"

FTPService='pure-ftpd'

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
		echo "Portage distfiles directory mounted in the system."
	fi

	# mount it into the FTP directory
	if [[ -r "${FTPDISTFILE%%/}/Unmounted." ]]; then
		mount "$FTPDISTFILE"
		LASTFATAL "Can't mount portage distfile directory ('${FTPDISTFILE}') into FTP area."
		echo "Portage distfiles directory mounted for FTP access."
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
	if ! rc-service "$FTPService" status >& /dev/null ; then
		rc-service "$FTPService" start
		LASTFATAL "Can't start FTP server."
	fi
	
	return 0
} # Start()


function Stop() {
	local res

	# stop the FTP server
	if rc-service "$FTPService" status >& /dev/null ; then
		rc-service "$FTPService" stop
		LASTERROR "Can't stop FTP server."
	fi

	# stop the rsync server
	if rc-service rsyncd status >& /dev/null ; then
		rc-service rsyncd stop
		LASTERROR "Can't stop rsync server."
	fi

	# umount FTP directory
	if [[ ! -r "${FTPDISTFILE%%/}/Unmounted." ]]; then
		umount "$FTPDISTFILE"
		LASTERROR "Can't unmount FTP area ('${FTPDISTFILE}')."
		echo "Portage distfiles directory not available for FTP access anymore."
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

