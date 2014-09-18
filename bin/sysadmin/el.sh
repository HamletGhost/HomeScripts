#!/bin/sh

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

if [[ -z "${PORTAGEDIRS[*]}" ]]; then
	declare -a PORTAGEDIRS=( "/usr/local/portage" "/usr/portage" )
fi

equery list "$@" | while read PkgKey ; do
	Category="${PkgKey%/*}"
	EBuild="${PkgKey#*/}"
	Found=0
	DBG "Package key: '${Category}/${EBuild}'"
	for PortageDir in "${PORTAGEDIRS[@]}" ; do
		DBG "Trying portage dir '${PortageDir}'"
		Package="$EBuild"
		while [[ ! -d "${PortageDir}/${Category}/${Package}" ]]; do
			DBG "- tested: '${Package}'"
		 	NewPackage="${Package%-*}"
			[[ "$NewPackage" == "$Package" ]] && break
			Package="$NewPackage"
		done
		if [[ -n "$Package" ]] && [[ -d "${PortageDir}/${Category}/${Package}" ]]; then
			echo "${Category}/${Package}"
			Found=1
			break
		fi
	done
	isFlagSet Found || STDERR "'${PkgKey}' not found!"
done

