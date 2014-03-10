#!/bin/bash

: ${LOGPATTERN:="*.log"}

function STDERR() {
	echo "$*" >&2
}

function ERROR() {
	STDERR "Error: $*"
}

function FATAL() {
	local Code="$1"
	shift
	STDERR "Fatal error (${Code}): $*"
	exit $Code
}

function InterruptHandler() {
	STDERR "This was: '${LogFile}'"
}


LogDir="${1:-.}"
if [[ -f "$LogDir" ]]; then
	LogFile="$LogDir"
else
	[[ -n "$LogDir" ]] && LogDir="${LogDir%%/}/"
	for SubLogDir in '' 'log' 'logs' ; do
		LogFile="$(find "${LogDir}${SubLogDir:+${SubLogDir}/}" -name "$LOGPATTERN" | xargs ls -rt 2> /dev/null | tail -n 1)"
		[[ -f "$LogFile" ]] && break
	done
	[[ -f "$LogFile" ]] && echo "Log file: '${LogFile}'"
fi

if [[ -z "$LogFile" ]]; then
	FATAL 2 "No log file found in '${LogDir}'."
elif [[ ! -r "$LogFile" ]]; then
	FATAL 2 "Log file '${LogFile}' is not readable."
fi

trap InterruptHandler INT
tailf "$LogFile"

