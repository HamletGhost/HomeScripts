#!/bin/bash
#
# Prints accessibility information about a file.
# Use '--help' for instructions.
#

SCRIPTNAME="$(basename "$0")"


function STDERR() {
	echo "$*" >&2
}

function FATAL() {
	local -i Code=$1
	shift
	STDERR "FATAL (${Code}): $*"
	exit $Code
} # FATAL()

function isFlagSet() {
	local VarName="$1"
	[[ -n "${!VarName//0}" ]]
}

function isDebugging() {
	local Level="${1:-1}"
	isFlagSet DEBUG && [[ "$DEBUG" -ge "$Level" ]]
} # isDebugging()

function DBGN() {
	local -i Level="$1"
	shift
	isDebugging $Level && STDERR "DBG| $*"
}

function DBG() { DBGN 1 "$@" ; }

function DUMPVAR() {
	local VarName="$1"
	DBG "'${VarName}'='${!VarName}'"
}

function DUMPVARS() {
	local VarName
	for VarName in "$@" ; do
		DUMPVAR "$VarName"
	done
}


function help() {
	cat <<-EOH
	Reports the accessibility of specified file.
	
	Usage:  ${SCRIPTNAME}  [options] [--|-] [file ...]
	
	If file is not speficied, current directory will be tested.
	If group is not specified, the main group of the current user will be tested.
	If user is not specified, the current user is used.
	
	Options:
	--user=USER [${USER}]
	    tests for the specified user
	--group=GROUP []
	    tests for a user in the specified group
	--debug[=LEVEL] [${DEBUG}]
	    set the verbosity level
	--help , -h , -?
	    prints this help
	EOH
} # help()

function ExpandUserID() {
	# parameter: user name or ID
	# output: user ID
	local User="$1"
	if [[ -n "${User//[0-9]}" ]]; then
		# if not a plain number, assume it's a user ID already
		UserID="$(id -u "$User")"
		[[ -n "$UserID" ]] && User="$UserID"
	fi
	echo "$User"
} # ExpandUserID()

function ExpandGroupID() {
	# parameter: group name or ID
	# output: group ID
	local Group="$1"
	if [[ -n "${Group//[0-9]}" ]]; then
		# if not a plain number, assume it's a group ID already
		GroupID="$(id -g "$Group")"
		[[ -n "$GroupID" ]] && Group="$GroupID"
	fi
	echo "$Group"
}

################################################################################
function PrintAccess() {
	local File="$1"
	local FullPath="$(readlink -f "$File")"
	
	local -i Levels=0
	local -a Paths
	
	local TempPath="$FullPath"
	while [[ -n "$TempPath" ]] ; do
		Paths[Levels++]="$TempPath"
		NewTempPath="$(dirname "$TempPath")"
		[[ "$NewTempPath" == "$TempPath" ]] && break
		TempPath="$NewTempPath"
	done
	
	local LastRead LastWrite LastExec
	local -i iPath
	for (( iPath = $Levels ; iPath > 0 ; --iPath )); do
		local Path="${Paths[iPath-1]}"
		DBG "Checking level ${iPath}: '${Path}'"
		
		local -a ls_items=( $(ls -dln "$Path") )
		local Access="${ls_items[0]}"
		local FileUserID="${ls_items[2]}"
		local FileGroupID="${ls_items[3]}"
		if [[ "$FileUserID" == "$User" ]]; then
			local AccessUser="${Access:1:3}"
		elif [[ "$GroupUserID" == "$Group" ]]; then
			local AccessUser="${Access:4:3}"
		else
			local AccessUser="${Access:7:3}"
		fi
		DBG "'${Path}': user ${FileUserID} group ${FileGroupID} access='${AccessUser}'"
		if [[ "${AccessUser:0:1}" != '-' ]]; then
			if [[ "$LastExec" == $iPath ]] || [[ $iPath == $Levels ]]; then
				LastRead=$((iPath-1))
			fi
		fi
		if [[ "${AccessUser:1:1}" != '-' ]]; then
			if [[ "$LastExec" == $iPath ]] || [[ $iPath == $Levels ]]; then
				LastWrite=$((iPath-1))
			fi
		fi
		if [[ "${AccessUser:2:1}" != '-' ]]; then
			if [[ "$LastExec" == $iPath ]] || [[ $iPath == $Levels ]]; then
				LastExec=$((iPath-1))
			fi
		fi
		
	done
	
	if [[ -n "$LastRead" ]]; then
		echo "Read access: '${Paths[LastRead]}'"
	else
		echo "Read access: none"
	fi
	
	if [[ -n "$LastWrite" ]]; then
		echo "Write access: '${Paths[LastWrite]}'"
	else
		echo "Write access: none"
	fi
	
	if [[ -n "$LastExec" ]]; then
		echo "Exec access: '${Paths[LastExec]}'"
	else
		echo "Exec access: none"
	fi
} # PrintAccess()

### main script ################################################################
declare -i NoMoreOptions=0
declare UserParam GroupParam

for (( iParam = 1 ; iParam <= $# ; ++iParam )); do
	Param="${!iParam}"
	if [[ "${Param:0:1}" != '-' ]] || isFlagSet NoMoreOptions ; then
		Paths=( "${Paths[@]}" "$Param" )
	else
		case "$Param" in
			( '--user='* )  UserParam="${Param#--*=}" ;;
			( '--group='* ) GroupParam="${Param#--*=}" ;;
			( '--debug='* ) DEBUG="${Param#--*=}" ;;
			( '--debug' | '-d' )   DEBUG=1 ;;
			( '--' | '-' )  NoMoreOptions=1 ;;
			( '--help' | '-h' | '-?' ) DoHelp=1 ;;
			( * ) FATAL 1 "Unsupported option: '${Param}'. Use with '--help' for usage directions." ;;
		esac
	fi
done

if isFlagSet DoHelp ; then
	help
	exit
fi

# which group?
Group=$(ExpandGroupID "${GroupParam:-$(id -g)}")

# which user?
User="$(ExpandUserID "${UserParam:-${UID}}")"

DBG "Looking for user='${User}' and group='${Group}'"

# parse the path
declare -i NPaths="${#Paths[@]}"
for File in "${Paths[@]}" ; do
	[[ $NPaths -gt 1 ]] && echo "${File}:"
	PrintAccess "$File"
done

