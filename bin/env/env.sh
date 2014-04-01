#!/bin/bash
#
# bash script which is supposed to be sourced - no new shells are opened,
# no exit statement is used
#

: ${EnvDir:="${1:-${HOME}/env.d}"}

if [[ -d "$EnvDir" ]]; then
	for EnvFile in ${EnvDir}/*.sh ; do
		# skip non-executable and backup files:
		if [[ ! -x "$EnvFile" ]] || [[ "${EnvFile: -1}" == '~' ]]; then
		#	echo "'${EnvFile}' skipped"
			continue
		fi
	#	echo "Configuration: $(basename "$EnvFile")"
	        source "$EnvFile"
	done
	unset EnvFile
fi
unset EnvDir

