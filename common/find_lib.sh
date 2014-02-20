#!/bin/sh

SCRIPTNAME="$(basename "$0")"

: ${find:='find'}
: ${tr:='tr'}
: ${sort:='sort'}

: ${LDCACHE:="/etc/ld.so.conf"}

function isFlagSet() {
	local VarName="$1"
	[[ -n "${!VarName//0/}" ]]
}

function isDebugging() {
	isFlagSet DEBUG
}

function ERROR() {
	echo "$*" >&2
}

function DBG() {
	isDebugging && ERROR "$*"
}

function help() {
	cat <<-EOH
	Finds the specified library.
	
	Usage:  ${SCRIPTNAME}  LibName [LibName ...] 
	
EOH
}

function ExpandLibSpec() {
	local LibSpec="$1"
	[[ "${LibSpec#lib}" == "$LibSpec" ]] && echo -n 'lib'
	echo -n "$LibSpec"
	[[ "${LibSpec%\*}" == "$LibSpec" ]] && echo -n '*'
	echo
}

function ExpandPath() {
	local Path
	while read Path ; do
		readlink -f "$Path"
	done
}

if [[ -z "$1" ]] || [[ "$1" == '--help' ]] || [[ "$1" == '-h' ]] ; then
	help
	exit
fi

declare -a LibraryPaths
# echo "$LD_LIBRARY_PATH" | $tr ':' '\n' | $sort -u 
while read LibPath ; do
	LibraryPaths[${#LibraryPaths[*]}]="$LibPath"
done 0< <(grep -v '^ *#' "$LDCACHE" ; echo "$LD_LIBRARY_PATH" | $tr ':' '\n' | ExpandPath | $sort -u)

if isDebugging ; then
	DBG "Library paths:"
	for LibPath in "${LibraryPaths[@]}" ; do
		DBG "- '${LibPath}'"
	done
fi

declare -i nNotFound=0
for LibSpec in "${LibraryPaths[@]}" ; do
	LibPattern="$(ExpandLibSpec "$LibSpec")"
	
	if $find "${LD_LIBRARY_PATH/:/ }" -name "$LibPattern" ; then
		ERROR "No library matching '${libpattern}' found (specification: '${LibSpec}')"
		let ++nNotFound
	fi
done

[[ $nNotFound != 0 ]] && exit 1
exit 0

