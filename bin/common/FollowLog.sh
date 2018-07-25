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
	[[ -n "$LogDir" ]] && LogDir="${LogDir%%/}"
	for SubLogDir in ':' 'log' 'logs' '' ; do
		if [[ "${SubLogDir:0:1}" == ':' ]]; then
			Depth=0
			SubLogDir="${SubLogDir#:}"
		else
			Depth=''
		fi
		CandidateLogDir="${LogDir}${SubLogDir:+/${SubLogDir}}"
		: ${CandidateLogDir:="."}
		[[ -d "$CandidateLogDir" ]] || continue
		LogFile="$(find -L "$CandidateLogDir" ${Depth:+-maxdepth "$Depth"} -type f -name "$LOGPATTERN" | xargs ls -drt 2> /dev/null | tail -n 1)"
		[[ "$LogFile" == '.' ]] && LogFile="" && continue # if find finds nothing, ls will show "."
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

