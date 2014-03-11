#!/bin/bash
#
# Renames files with a numeric suffix
#
# Use with --help for usage instructions.
#
# Vesion history:
# 1.0 (petrillo@fnal.gov)
#     first version
# 1.1 (petrillo@fnal.gov)
#     user interface
#

SCRIPTNAME="$(basename "$0")"
SCRIPTVERSION="1.0"

: ${POLLDELAY:="60"}
: ${COLUMNS:=80}
: ${PSOPTS:="-o user,pid,ppid,stat,psr,pcpu,pmem,sz,rss,vsz,stime,etime,cputime,tt"}

function help() {
	cat <<-EOH
	Continuously prints information about a process.
	
	Usage:  ${SCRIPTNAME}  PID
	
	Options:
	--every=SECONDS ['${POLLDELAY}']
	    print statistics every SECONDS
	--hdrevery=LINES ['${HeaderEvery}']
	    print a header every LINES lines (0 disables the header completely)
	--cols=COLUMNS ['${COLUMNS}']
	    the number of columnson the screen (autodetection seems to fail...)
	--psopts= ['${PSOPTS}']
	    the ps program options to be used
	--memmap=MAPNAME
	    if specified, on each print the memory map is also saved as a file named
	    MAPNAME; a string %TIME% in the MAPNAME is replaced by the current date
	    and time, up to the seconds
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



function PrintProcess() {
	local PID
	local res=1
	local LogFile=''
	local Line=""
	for PID in "$@" ; do
		[[ -z "$PID" ]] && break
		[[ -n "${PID//[0-9]}" ]] && LogFile="$PID" && break
		[[ -n "$Line" ]] && echo "$Line"
		Line="$(ps --no-header $PSOPTS "$PID")"
		[[ $? == 0 ]] && res=0
	done
	if [[ -n "$LogFile" ]]; then
		if [[ -r "$LogFile" ]]; then
			Line+=" | log: $(wc -l < "$LogFile") lines"
		else
			Line+=" | (log not found)"
		fi
	fi
	echo "$Line"
	return $res
} # PrintProcess()


function GetDateTag() {
	printf "%-30s" "$(date)"
}

function GetPID() {
	local ProgName="$1"
	
	if [[ -d "/proc/${ProgName}/fd" ]]; then
		echo "$ProgName"
		return 0
	fi
	
	local -a PIDs=( $(pgrep "$ProgName") )
	local -i nPIDs="${#PIDs[@]}"
	local PID=0
	if [[ $nPIDs == 0 ]]; then
		echo "No process matching '${ProgName}'." >&2
		echo "$ProgName"
		return 1
	elif [[ $nPIDs -gt 1 ]]; then
		echo "${nPIDs} processes match '${ProgName}':"
		for PID in "${PIDs[@]}" ; do
			PrintProcess "$PID"
		done
		echo "Monitoring: '${PID}'"
	else
		PID="${PIDs[0]// }"
	fi
	echo "$PID"
	return 0
} # GetPID()


function SaveMemMaps() {
	local PID="$1"
	local MapFile="${2:-"memmaps-${PID}.txt"}"
	
	local DateTag="$(date '+%Y%m%d%H%M%S')"
	MapFile="${MapFile//%TIME%/${DateTag}}"
	[[ -r "/proc/${PID}/maps" ]] || return 2
	cp -a "/proc/${PID}/maps" "$MapFile" && chmod u+w "$MapFile"
} # SaveMemMaps()


################################################################################
declare DoHelp=0 DoVersion=0 OnlyPrintEnvironment=0 NoLogDump=0

declare HeaderEvery=25

declare -i NoMoreOptions=0
declare -a Processes
declare -i nProcesses=0
for (( iParam = 1 ; iParam <= $# ; ++iParam )); do
	Param="${!iParam}"
	if ! isFlagSet NoMoreOptions && [[ "${Param:0:1}" == '-' ]]; then
		case "$Param" in
			( '--help' | '-h' | '-?' )     DoHelp=1  ;;
			( '--version' | '-V' )         DoVersion=1  ;;
			
			### behaviour options
			( '--every='* )    POLLDELAY="${Param#--*=}" ;;
			( '--hdrevery='* ) HeaderEvery="${Param#--*=}" ;;
			( '--cols='* )     COLUMNS="${Param#--*=}" ;;
			( '--psopts='* )   PSOPTS="${Param#--*=}" ;;
			( '--memmap='* )   MEMMAP="${Param#--*=}" ;;
			( '--logfile='* )  LogFile="${Param#--*=}" ;;
			
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
		Processes[nProcesses++]="$Param"
	fi
done

declare -i ExitCode

if isFlagSet DoVersion ; then
	echo "${SCRIPTNAME} version ${SCRIPTVERSION:-"unknown"}"
	: ${ExitCode:=0}
fi

if isFlagSet DoHelp || [[ $nProcesses -le 0 ]] ; then
	help
	# set the exit code (0 for help option, 1 for missing parameters)
	isFlagSet DoHelp
	{ [[ -z "$ExitCode" ]] || [[ "$ExitCode" == 0 ]] ; } && ExitCode="$?"
fi

[[ -n "$ExitCode" ]] && exit $ExitCode

if [[ -z "$1" ]] || [[ "$1" == "-h" ]] || [[ "$1" == "-?" ]] || [[ "$1" == "--help" ]]; then
	help
	exit
fi

ProcessSpec="${Processes[0]}"
PID="$(GetPID "${Processes[0]}")"

if [[ -z "$PID" ]] || [[ ! -d "/proc/${PID}" ]]; then
	echo "$(GetDateTag) - no process ${ProcessSpec} is currently running."
	exit 1
fi

# build the header line
DateTag="$(GetDateTag)"
HeaderLine="$(printf "%-${#DateTag}s" "Hit <Ctrl>+<C> to exit" | cut -c 1-${#DateTag} ) | $(ps $PSOPTS "$PID" | head -n 1)"
unset DateTag

for (( iPolls = 0 ;; ++iPolls )); do
	[[ -d "/proc/${PID}" ]] || break
	if [[ $HeaderEvery -gt 0 ]] && [[ $((iPolls % $HeaderEvery)) == 0 ]]; then
		echo "$HeaderLine" | cut -c 1-${COLUMNS}
	fi
	echo "$(GetDateTag) | $(PrintProcess "$PID" "$LogFile" )" | cut -c 1-${COLUMNS}
	[[ -n "$MEMMAP" ]] && SaveMemMaps "$PID" "$MEMMAP"
	sleep $POLLDELAY
done
echo "$(GetDateTag) | Process $PID has ended."
