#!/bin/sh
#
#
#

SCRIPTNAME="$(basename "$0")"

: ${player:="mplayer"}
: ${SIGTERM:="HUP"}

declare -i NSleeps=0
declare -i -a SleepPIDs

function help() {
	cat <<-EOH
		Writes the content of the specified real-time audio stream.
		
		Usage: ${SCRIPTNAME} [options] SourceStream Duration [Delay] [OutputStream] [-- ripper options]
		
		Note that the duration includes dead-times for buffering and similar - in other words,
		it's the total time the audio ripping process will run.
	EOH
} # help()


function STDERR() {
	echo "$*" >&2
} # STDERR()

function ERROR() {
	STDERR "ERROR: $*"
} # ERROR()

function FATAL() {
	local Code="$1"
	shift
	STDERR "FATAL ERROR (${Code}): $*"
	exit $Code
} # FATAL()

function LASTFATAL() {
	local Code="$1"
	[[ $Code == 0 ]] && return 0
	FATAL "$Code" "$@"
} # LASTFATAL()

function isFlagSet() {
	local VarName="$1"
	[[ -n "${!VarName//0}" ]]
} # isFlagSet()

function isProcess() {
	local -i PID="$1"
	[[ -r "/proc/$PID" ]]
} # isProcess()


function StopSleeping() {
	local ManageTraps="${1:-1}"
	# this uses a global variable!
#	echo "${NSleeps} processes left; killing the last one."
	if [[ $NSleeps -gt 0 ]]; then
		isFlagSet ManageTraps && trap - SIGCHLD
		kill -TERM "${SleepPIDs[--NSleeps]}"
		isFlagSet ManageTraps && trap StopSleeping SIGCHLD
	fi
} # StopSleeping()

function WaitForProcess() {
	# WaitForProcess PID WaitTime
	# At most WaitTime is waited for PID to terminate.
	#
	#

	local -i PID="$1"
	local Time="$2"
	
	sleep "$Time" &
	local SleepID=$!
	SleepPIDs[NSleeps++]="$SleepID"
	trap StopSleeping SIGCHLD
	wait $SleepID
	if isProcess "$SleepID" ; then
		trap - SIGCHLD
		StopSleeping 0
		return 0
	elif isProcess "$PID" ; then
		return 1
	else
		echo "$PID is not running, but we didn't realize that!"
		return 0
	fi
} # WaitForProcess()


### parameters loop ###########################################################

declare -a Params
declare -i NParams=0
declare -a Options
declare -i NOptions=0

for Param in "$@" ; do
	if isFlagSet NoMoreOptions ; then
		Options[NOptions++]="$Param"
	elif [[ "${Param:0:1}" == '-' ]]; then
		case "$Param" in
			( '--help' | '-h' | '-?' )
				DoHelp=1
				;;
			( '--' )
				NoMoreOptions=1
				;;
			( * )
				FATAL 1 "Unrecognized option - '${Param}'; use \`${SCRIPTNAME} --help\` for usage instructions."
				;;
		esac
	else
		Params[NParams++]="$Param"
	fi
done


if isFlagSet DoHelp ; then
	help
	exit 1
fi

if [[ $NParams -lt 1 ]]; then
	help
	FATAL 1 "not enough parameters in command line."
fi

# parameters setting
InputStream="${Params[0]}"
Duration="${Params[1]}"
Delay="${Params[2]:=0}"
OutputFile="${Params[3]:="${InputStream##*/}"}.dump"

# output file check
touch "$OutputFile"
LASTFATAL $? "Can't write on output file '${OutputFile}'"

# wait for the right time
MyPID="$$"
if [[ $Delay != 0 ]]; then
	echo "Dumping of ${Duration} seconds of audio stream '${InputStream}' into file '${OutputFile}' is scheduled for ${Delay} seconds from now."
	sleep $Delay
fi

# run the player/ripper
echo "Dumping of ${Duration} seconds of audio stream '${InputStream}' into file '${OutputFile}' is scheduled for ${Delay} seconds from now."
$player -dumpaudio -dumpfile "$OutputFile" "${Options[@]}" $(< media/music/radio/WFMT.url ) &
PID=$!

# wait for the victim
if [[ $Duration == 0 ]]; then
	echo "No duration set - you will have to interrupt the process PID=${PID} manually."
	wait $PID
else
	set -o monitor
	sleep $Duration
	kill -${SIGTERM} "$PID"
	echo "Ripping process (PID=${PID}) has been asked to stop."
	WaitForProcess $PID 5
	[[ $? != 0 ]] && kill -${SIGTERM} "$PID" && echo "Ripping process (PID=${PID}) has been asked to stop - again."
	WaitForProcess $PID 5
	[[ $? != 0 ]] && kill -KILL "$PID" && echo "Ripping process (PID=${PID}) has been executed for insubordination."
fi

