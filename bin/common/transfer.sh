#!/bin/sh

SCRIPTNAME="$(basename "$0")"

function isFlagSet() {
	local VarName="$1"
	[[ -n "${!VarName//0}" ]]
} # isFlagSet()


function help() {
	cat <<EOH
Moves files in another location, then puts a link to them where they were before.

Usage:  ${SCRIPTNAME} Source [Source ...] DestDir

Options:
-v , --verbose
    writes each action performed

EOH
} # help()


declare -i NoMoreOptions=0
declare -a Params
declare -i nParams=0
for (( iParam = 1 ; iParam <= $# ; ++iParam )); do
	Param="${!iParam}"
	if ! isFlagSet NoMoreOptions && [[ "${Param:0:1}" == '-' ]]; then
		case "$Param" in
			( '--help' | '-h' | '-?' )
				DoHelp=1
				;;
			( '-v' | '--verbose' )
				VERBOSE=1
				;;
			( '-' | '--' )
				NoMoreOptions=1
				;;
			( * )
				echo "Unrecognized option #${iParam} - '${Param}'"
				exit 1
				;;
		esac
	else
		Params[nParams++]="$Param"
	fi
done

if isFlagSet DoHelp ; then
	help
	exit
fi

# get the destination from the last parameter, and remove it from the list
DestDir="${Params[--nParams]}"
DestDir="${DestDir%/}"
unset Params[nParams]

for Param in "${Params[@]}" ; do
	SrcBaseName="$(basename "$Param")"
	mv ${VERBOSE:+-v} "$Param" "${DestDir}/${SrcBaseName}" && ln -s${VERBOSE:+v} "${DestDir}/${SrcBaseName}" "$Param"
done
