#!/bin/bash
#
# Prints on screen the specified scripts
#

: ${OPENWITH:=less}

declare -i nErrors=0
declare -a Scripts
for ScriptName in "$@" ; do
	ScriptPath="$(which "$ScriptName")"
	: ${ScriptPath:="$ScriptName"}
	if [[ ! -r "$ScriptPath" ]]; then
		echo "ERROR: '${ScriptName}' not found." >&2
		let ++nErrors
		continue
	fi
	Scripts=( "${Scripts[@]}" "$ScriptPath" )
done

$OPENWITH "${Scripts[@]}"
res=$?
[[ $res != 0 ]] && exit $res
exit $nErrors

