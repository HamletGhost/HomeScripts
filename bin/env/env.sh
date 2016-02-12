#!/bin/bash
#
# bash script which is supposed to be sourced - no new shells are opened,
# no exit statement is used
#


function LoadEnvironment() {
	local EnvDir="${1:-"${HOME}/env.d"}"
	
	[[ -d "$EnvDir" ]] || return 1
	local EnvFile
	for EnvFile in "${EnvDir}/"*.sh ; do
		# skip non-executable and backup files:
		if [[ ! -x "$EnvFile" ]] || [[ "${EnvFile: -1}" == '~' ]]; then
		#	echo "'${EnvFile}' skipped"
			continue
		fi
	#	echo "Configuration: $(basename "$EnvFile")"
	        source "$EnvFile"
	done
} # LoadEnvironment()

LoadEnvironment "$@"
unset LoadEnvironment

