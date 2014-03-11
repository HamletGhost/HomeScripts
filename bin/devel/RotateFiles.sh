#!/bin/bash
#
# Renames files with a numeric suffix
#
# Use with --help for usage instructions.
#
# Vesion history:
# 1.0 (petrillo@fnal.gov)
#     first version
#

SCRIPTNAME="$(basename "$0")"
SCRIPTVERSION="1.0"


function help() {
	cat <<-EOH
	Renames files with a numeric suffix.
	
	Usage:  ${SCRIPTNAME} [options] File [File ...]
	
	The files are renamed into File.1, File.2, etc.
	The original file names are printed on screen; this allows for example:
	cp -a Original.txt "\$(${SCRIPTNAME} Backup.txt)"
	
	Options:
	-n Limit
	    if renaming goes beyond the limit, the volume with the highest numbre is
	    deleted
	--padding=NCHAR , -p NCHAR
	    use 0-padded volume numbers with this padding
	--quiet
	    do not print the original file name after renaming has happened
	EOH
} # help()


function isFlagSet() {
	local VarName="$1"
	[[ -n "${!VarName//0}" ]]
} # isFlagSet()

function isFlagUnset() {
	local VarName="$1"
	[[ -z "${!VarName//0}" ]]
} # isFlagUnset()

function STDERR() { echo "$*" >&2 ; }
function ERROR() { STDERR "ERROR: $@" ; }
function FATAL() {
	local Code="$1"
	shift
	STDERR "FATAL ERROR (${Code}): $*"
	exit $Code
} # FATAL()
function LASTFATAL() {
	local Code="$?"
	[[ "$Code" != 0 ]] && FATAL "$Code""$@"
} # LASTFATAL()


function PadNumber() {
	local -i Number="$1"
	local -i Padding="$2"
	if [[ -n $Padding ]] && [[ $Padding -gt 0 ]]; then
		printf "%0*d" "$Number"
	else
		printf "%d" "$Number"
	fi
} # PadNumber()


function RotateFile() {
	local FilePath="$1"
	local -i Limit="$2"
	local -i Padding="$3"
	
	[[ -r "$FilePath" ]] || return 2
	
	# find the next free file
	local NextFree LastHeld
	local -i iFreeVolume=0
	while true ; do
		let ++iFreeVolume
		NextFree="${FilePath}.$(PadNumber "$iFreeVolume" "$Padding")"
		[[ -r "$NextFree" ]] || break
		LastHeld="$NextFree"
	done
	# if we have a limit and there are more files than this limit allows,
	# do not increase the number of files (i.e., delete the last one)
	if [[ -n "$Limit" ]] && [[ "$Limit" -gt 0 ]] && [[ $iFreeVolume -gt $Limit ]]; then
		rm -f "$LastHeld"
	fi
	while [[ $iFreeVolume -ge 2 ]]; do
		local NewVolume="${FilePath}.$(PadNumber "$iFreeVolume" "$Padding")"
		local OldVolume="${FilePath}.$(PadNumber "$((--iFreeVolume))" "$Padding")"
		[[ -r "$OldVolume" ]] && mv "$OldVolume" "$NewVolume"
	done
	mv "$FilePath" "${FilePath}.$(PadNumber 1 "$Padding")"
	isFlagSet BeQuiet || echo "$FilePath"
} # RotateFile()


################################################################################
declare DoHelp=0 DoVersion=0 OnlyPrintEnvironment=0 NoLogDump=0

declare -i Limit=0
declare -i Padding=0

declare -i NoMoreOptions=0
declare -a Files
declare -i nFiles=0
for (( iParam = 1 ; iParam <= $# ; ++iParam )); do
	Param="${!iParam}"
	if ! isFlagSet NoMoreOptions && [[ "${Param:0:1}" == '-' ]]; then
		case "$Param" in
			( '--help' | '-h' | '-?' )     DoHelp=1  ;;
			( '--version' | '-V' )         DoVersion=1  ;;
			( '--quiet' | '-q' )           BeQuiet=1  ;;
			
			### behaviour options
			( '-n' )                       let ++iParam ; Limit="${!iParam}" ;;
			( '-p' )                       let ++iParam ; Padding="${!iParam}" ;;
			( '--padding='* )              Padding="${Param#--*=}" ;;
			
			### other stuff
			( '-' | '--' )
				NoMoreOptions=1
				;;
			( * )
				FATAL 1 "Unrecognized script option #${iParam} - '${Param}'"
				;;
		esac
	else
		NoMoreOptions=1
		Files[nFiles++]="$Param"
	fi
done

declare -i ExitCode

if isFlagSet DoVersion ; then
	echo "${SCRIPTNAME} version ${SCRIPTVERSION:-"unknown"}"
	: ${ExitCode:=0}
fi

if isFlagSet DoHelp || [[ $nFiles -le 0 ]] ; then
	help
	# set the exit code (0 for help option, 1 for missing parameters)
	isFlagSet DoHelp
	{ [[ -z "$ExitCode" ]] || [[ "$ExitCode" == 0 ]] ; } && ExitCode="$?"
fi

[[ -n "$ExitCode" ]] && exit $ExitCode


declare -i nErrors=0
for File in "${Files[@]}" ; do
	RotateFile "$File" "$Limit" "$Padding"
	res=$?
	[[ $res != 0 ]] && let ++nErrors
done
exit $nErrors
