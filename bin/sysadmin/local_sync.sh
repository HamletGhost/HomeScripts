#!/bin/sh
#
# Start with `--help` for usage instructions.
#

SCRIPTNAME="$(basename "$0")"

REMOTESETUPSCRIPT="bin/PortageFTPserver.sh"

: ${TARGET:="world"}
: ${DEFAULTSERVER:="glamis.thebard.net"}

declare -ar Servers=( "glamis.thebard.net" "malvolio.thebard.net" )

MakeConf="/etc/portage/make.conf"

Services=( 'rsyncd' 'pure-ftpd' )

function STDERR() { echo "$*" >&2 ; } 

function ERROR() { STDERR "ERROR: $*" ; }

function FATAL() {
	local Code="$1"
	shift
	STDERR "FATAL (${Code}): $*"
	exit $Code
} # FATAL()

function isFlagSet() {
	local VarName="$1"
	[[ -n "${!VarName//0}" ]]
}

function isDebugging() { isFlagSet DEBUG ; }

function DBG() { isDebugging && STDERR "$*" ; }

function DUMPVAR() {
	local VarName="$1"
	DBG "${VarName}='${!VarName}'"
}

function DUMPVARS() {
	for VarName in "$@" ; do
		DUMPVAR "$VarName"
	done
}
function ExtractVariable() {
	# doesn't work :-(
	local SrcFile="$1"
	local VarName="$2"
	echo $( source "$SrcFile" ; echo "\${$VarName}" )
}

function ExtractVariable2() {
	local SrcFile="$1"
	local VarName="$2"
	ConfLine="$(grep "^${VarName}=" "$SrcFile" | tail -n 1)"
	Content="${ConfLine#${VarName}=\"}"
	Content="${Content%\"*}"
	echo "$Content"
}


function AllServices() {
	for Service in "${Services[@]}" ; do
		if [[ "$1" == "Start" ]]; then
			ssh "$SERVER" /sbin/rc-service "$Service" status || ssh "$SERVER" /sbin/rc-service "$Service" start
		else
			ssh "$SERVER" /sbin/rc-service "$Service" "$@"
		fi
		res=$?
		[[ $res != 0 ]] && return $res
	done
	return 0
}

function RemoteSetup() {
	ssh "$SERVER" "$REMOTESETUPSCRIPT" "$@"
} # RemoteSetup()

function MountRemoteDir() {
	local Dir
	for Dir in "$@" ; do
		ssh "$SERVER" mount "$Dir"
	done
}

function MountRemoteDirs() {
	local Dir
	for Dir in "/usr/portage" "/usr/portage/distfiles" ; do
		MountRemoteDir "$Dir" >& /dev/null
	done
}


function help()	{
	cat <<EOH
Syncronizes portage database from a local repository.

Usage:  ${SCRIPTNAME} [options]

The following actions happen:
1. cleans unused packages from the distfiles local repository
2. synchronizes the portage tree from the SERVER remote host
3. fetches the packages required to emerge TARGET, downloading from SERVER as first choice,
	or any other available server if required file is not available there.
This script also tries to start the needed services on the remote host using a ssh
connection first; those services are not stopped by default after the script is done.

Options:
--dontclean , -C
	doesn't clean the current portage distfiles prior to fetch the new packages
--synconly , -s
	only performs portage tree synchronization (and cleaning, unless overridden)
--fetchonly , -f
	only performs packages fetch (and cleaning, unless overridden)
--stopservices , -S
	stop the services which are required by the script after having used them;
	DANGEROUS: services are stopped even if tey were started already when this script
	started.

Environment variables:
SERVER ('${SERVER}')
	the server to synchronize from
TARGET ('${TARGET}'}
	which target is used to fetch packages

EOH
}

### script starts here #########################################################

DoAll=1
declare -a Params
declare -i NParams=0
for (( iParam = 1 ; iParam <= $# ; ++iParam )); do
	Param="${!iParam}"
	if [[ "${Param:0:1}" == '-' ]] && ! isFlagSet NoMoreOptions ; then
		case "$Param" in
			( '--help' | '-h' | '-?' )
				DoHelp=1
				;;
			( '--fetchonly' | '-f' )
				DoFetch=1
				DoAll=0
				;;
			( '--dontclean' | '-C' )
				DontClean=1
				;;
			( '--synconly' | '-s' )
				DoSync=1
				DoAll=0
				;;
			( '--stop' | '-S' )
				STOP=1
				;;
			( '--debug' )
				DEBUG=1
				;;
			( '--' )
				NoMoreOptions=1
				;;
			( * )
				FATAL 1 "Unrecognized option - '${Param}'. Use '--help' for usage instructions."
				;;
		esac
	else
		Params[NParams++]="$Param"
	fi
done

if isFlagSet DoHelp ; then
	help
	exit
fi

if [[ -z "$SERVER" ]]; then
	if [[ "$NParams" -ge 1 ]]; then
		SERVER="${Params[0]}"
		ping -c 1 -w 2 -q "$SERVER" >& /dev/null || FATAL 1 "Can't contact server '${SERVER}'"
	else
		for SERVER in "${Servers[@]}" "" ; do
			[[ -n "$SERVER" ]] || continue
			# this server?
			[[ "$HOSTNAME" == "$SERVER" ]] && continue
			[[ "${SERVER#${HOSTNAME}.}" != "$SERVER" ]] && continue
			# does the server exist?
			ping -c 1 -w 2 -q "$SERVER" >& /dev/null || continue
		done
		[[ -z "$SERVER" ]] && FATAL 1 "No server available (tried: ${Servers[@]})"
	fi
fi


# set variables
PortageRsyncKey="gentoo-portage"
MirrorRsyncKey="gentoo-distfiles"

MySync="rsync://${SERVER}/${PortageRsyncKey}"
MyRep="ftp://${SERVER}/repository/gentoo-portage"

# get the current settings

GENTOO_MIRRORS="${MyRep} $(ExtractVariable2 "$MakeConf" "GENTOO_MIRRORS")"
echo "Portage will use as additional mirror: '${MyRep}'"

# source ${MakeConf}
# GENTOO_MIRRORS="${MyRep} ${GENTOO_MIRRORS}"

SYNC="$MySync"

DUMPVARS GENTOO_MIRRORS SYNC

# # first, make sure all the required services are up
# AllServices Start
RemoteSetup Start
res=$?

if [[ $res != 0 ]]; then
	echo "Error (${res}): unable to reach the server '${SERVER}'." >&2
#	exit $res
fi
#
# MountRemoteDirs

if ! isFlagSet DontClean ; then
	echo "Cleaning distribution files..."
	eclean-dist -d
	echo "Free space left:"
	df -h /usr/portage/distfiles
fi

if isFlagSet DoSync || isFlagSet DoAll  ; then
	SYNC="$SYNC" emerge --sync
	res=$?
	if [[ $res != 0 ]]; then
		echo "Sync exited with code ${res} (SYNC='${SYNC}')" >&2
	fi
else
	res=0
fi
if isFlagSet DoFetch || isFlagSet DoAll ; then
	if [[ $res == 0 ]]; then
		GENTOO_MIRRORS="$GENTOO_MIRRORS" emerge -DuN -f $TARGET
	else
		ERROR "error (code ${res}) while synching."
	fi
fi


# stop the services
isFlagSet STOP && RemoteSetup Stop

