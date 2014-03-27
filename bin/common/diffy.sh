#!/bin/bash

SCRIPTNAME="$(basename "$0")"
SCRIPTDIR="$(dirname "$0")"

: ${WIDTH:="$(sed -e 's/^diffy\([0-9]*\).sh$/\1/' <<< "$SCRIPTNAME" )"}

[[ "$WIDTH" == "$SCRIPTNAME" ]] && WIDTH=""
if [[ -z "$WIDTH" ]]; then
	[[ -z "$COLUMNS" ]] && eval $(resize)
	WIDTH="$COLUMNS"
fi

function isFlagSet() {
	local VarName="$1"
	[[ -n "${!VarName//0}" ]]
} # isFlagSet()

function STDERR() { echo "$*" >&2 ; }
function FATAL() {
	local -i Code=$1
	shift
	STDERR "FATAL (${Code}): $*"
	exit $Code
} # FATAL()


function ProcessInput() {
	local FileName="$1"
	case "${FileName##*.}" in
		( 'bz2' ) bzcat "$FileName" ;;
		( 'gz' ) zcat "$FileName" ;;
		( * ) cat "$FileName" ;;
	esac
} # ProcessInput()


declare -i nOptions=0
declare -a Options
declare -i nInputs=0
declare -a Inputs
declare -i NoMoreOptions=0
for (( iParam = 1 ; iParam <= $# ; ++iParam )); do
	Param="${!iParam}"
	
	if isFlagSet NoMoreOptions || [[ "${Param:0:1}" != '-' ]] && [[ -r "$Param" ]] ; then
		Inputs[nInputs++]="$Param"
	else
		case "$Param" in
			( '-' | '--' )
				NoMoreOptions=1
				;;
		esac
		Options[nOptions++]="$Param"
	fi
done

[[ $nInputs == 2 ]] || FATAL 1 "Exactly two input files must be specified -- found ${nInputs}."

diff -y ${WIDTH:+-W "${WIDTH}"} -b "${Options[@]}" <( ProcessInput "${Inputs[0]}" ) <( ProcessInput "${Inputs[1]}" ) | less -SRMr -x 8
