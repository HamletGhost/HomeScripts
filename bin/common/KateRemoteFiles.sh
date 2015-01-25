#!/bin/bash
#
# Opens many files in a new Kate session
#
# Usage:  KateRemoteFiles.sh  [@sessionname] BaseAddress RelPath [RelPath ...]
#

SCRIPTNAME="$(basename "$0")"

function help() {
	cat <<-EOH
	Opens many files in a new Kate session.
	
	Usage:  ${SCRIPTNAME} [options] [--] BaseAddress RelPath [RelPath ...]
	
	Options:
	--session=SESSIONNAME
	    opens kate with a session SESSIONNAME; by default no session is specified
	--help , -h , -?
	    prints this help
	
	All other options are passed to kate.
	EOH
} # help()


################################################################################

declare -i NoMoreOptions=0
declare -a RelPaths KateOptions
declare -i NRelPaths=0

declare SessionName

for (( iParam = 1 ; iParam <= $# ; ++iParam )); do
	
	Param="${!iParam}"
	if [[ "${Param:0:1}" == '-' ]] && [[ $NoMoreOptions == 0 ]]; then
		case "$Param" in
			( '--session='* )          SessionName="${Param#-*=}" ;;
			( '--help' | '-h' | '-?' ) DoHelp=1 ;;
			( '--' | '-' )             NoMoreOptions=1 ;;
			( * )
				KateOptions=( "${KateOptions[@]}" "$Param" )
				;;
		esac
	else
		if [[ -z "$BaseAddress" ]]; then
			BaseAddress="$Param"
		else
			RelPaths[NRelPaths++]="$Param"
		fi
	fi
	
done

if [[ "$DoHelp" == 1 ]]; then
	help
	exit
fi


# add a '/' at the end of the base path for convenience
BaseAddress="${BaseAddress%/}/"

[[ -n "$SessionName" ]] && KateOptions=( '--start' "$SessionName" "${KateOptions[@]}" )

echo "Opening ${NRelPaths} paths on '${BaseAddress}':"

declare -a Paths

for (( iPath = 0 ; iPath < $NRelPaths ; ++iPath )); do
	RelPath="${RelPaths[iPath]}"
	Path="${BaseAddress}${RelPath}"
	Paths[iPath]="$Path"
done

declare -a Command=( 'kate' "${KateOptions[@]}" '--' "${Paths[@]}" )

echo "${Command[@]}"
"${Command[@]}"
