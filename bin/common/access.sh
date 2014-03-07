#!/bin/sh
#
# Prints accessibility information about a file.
# Use '--help' for instructions.
#

SCRIPTNAME="$(basename "$0")"


function STDERR() {
	echo "$*" >&2
}

function isFlagSet() {
	local VarName="$1"
	[[ -n "${!VarName//0}" ]]
}

function isDebugging() {
	isFlagSet DEBUG
}

function DBG() {
	isDebugging && STDERR "DBG| $*"
}

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
	cat <<EOH
Reports the accessibility of specified file.

Usage:  ${SCRIPTNAME}  [file] [[user:]group]

If file is not speficied, current directory will be tested.
If group is not specified, the main group of the current user will be tested.
If user is not specified, the current user is used.

EOH
}

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


### main script ################################################################
for Param in "$@" ; do
	if [[ "$Param" == "--help" ]] || [[ "$Param" == "-h" ]] || [[ "$Param" == "-?" ]]; then
		help
		exit
	fi
done

# which group?
GroupParam="${2#*:}"
Group=$(ExpandGroupID "${GroupParam:-$(id -g)}")

# which user?
UserParam="${2%:*}"
User="$(ExpandUserID "${UserParam:-${UID}}")"

DBG "Looking for user='${User}' and group='${Group}'"

# parse the path
File="${1:-.}"

FullPath="$(readlink -f "$File")"

declare -i Levels=0
declare -a Paths

TempPath="$FullPath"
while [[ -n "$TempPath" ]] ; do
	Paths[Levels++]="$TempPath"
	NewTempPath="$(dirname "$TempPath")"
	[[ "$NewTempPath" == "$TempPath" ]] && break
	TempPath="$NewTempPath"
done

for (( iPath = $Levels ; iPath > 0 ; --iPath )); do
	Path="${Paths[iPath-1]}"
	DBG "Checking level ${iPath}: '${Path}'"
	
	declare -a ls_items=( $(ls -dln "$Path") )
	Access="${ls_items[0]}"
	FileUserID="${ls_items[2]}"
	FileGroupID="${ls_items[3]}"
	if [[ "$FileUserID" == "$User" ]]; then
		AccessUser="${Access:1:3}"
	elif [[ "$GroupUserID" == "$Group" ]]; then
		AccessUser="${Access:4:3}"
	else
		AccessUser="${Access:7:3}"
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
