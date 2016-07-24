#!/usr/bin/env bash
#
# Pipes all the specified executables into less
#

declare -a Execs=( "$@" )
declare -a Paths
declare TruePath
for Exec in "${Execs[@]}" ; do
	TruePath="$(which "$Exec" 2> /dev/null)"
	if [[ $? != 0 ]]; then
		echo "Executable '${Exec}' not found." >&2
		continue
	elif [[ ! -r "$TruePath" ]]; then
		echo "*** Skipping '${Exec}', it's not a file:"
		echo "$TruePath"
	else
		echo "*** '${Exec}' -> '${TruePath}'"
		Paths=( "${Paths[@]}" "$TruePath" )
	fi
done

less "${Paths[@]}"

