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
# 1.2 (petrillo@fnal.gov) 20140701
#     added peak memory detection
# 1.3 (petrillo@fnal.gov) 20140702
#     added resident memory peak detection too
# 1.4 (petrillo@fnal.gov) 20140814
#     added output to files
# 1.5 (petrillo@fnal.gov) 20161010
#     updated for OSX
# 1.6 (petrillo@slac.stanford.edu) 20241122
#     added --wait option
#

SCRIPTNAME="$(basename "$0")"
SCRIPTVERSION="1.6"

function isOSX() {
	[[ ! -d '/proc' ]] # this is not correct, but it's a shortcut
} # isOSX()


: ${POLLDELAY:="60"}
if isOSX ; then
	: ${PSOPTS:="-o user,pid,ppid,stat,pcpu,pmem,rss,vsz,stime,etime,cputime,tt"}
else
	: ${PSOPTS:="-o user,pid,ppid,stat,psr,pcpu,pmem,sz,rss,vsz,stime,etime,cputime,tt"}
fi
: ${DEFAULTMAPNAME:="memmap-%TIME%.txt"}

: ${Width:="$COLUMNS"}
if [[ -z "$Width" ]]; then
	eval $(resize)
	Width="$COLUMNS"
fi


function help() {
	cat <<-EOH
	Continuously prints information about a process.
	
	Usage:  ${SCRIPTNAME}  [PID|ProgramName]
	
	Options:
	--every=SECONDS ['${POLLDELAY}']
	    print statistics every SECONDS
	--wait=SECONDS
	    wait this long before giving up if the specified program is not detected
	--mempeak , --vmpeak
	    monitors the peak memory usage and prints it at the end of the process
	--hdrevery=LINES ['${HeaderEvery}']
	    print a header every LINES lines (0 disables the header completely)
	--cols=COLUMNS ['${Width}']
	    the number of columnson the screen (autodetection seems to fail...)
	--psopts= ['${PSOPTS}']
	    the ps program options to be used
	--memmap[=MAPNAME] [${DEFAULTMAPNAME}]
	    if specified, on each print the memory map is also saved as a file named
	    MAPNAME; a string %TIME% in the MAPNAME is replaced by the current date
	    and time, up to the seconds
	--logfile=LOGFILE
	    prints the current line of this log file (can have a slight delay)
	--output=OUTPUTFILE
	    appends the output to a file (can be specified multiple times)
	--stdout
	    writes the output on screen (default only if no output file is specified)
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
	local iParam
	for (( iParam = 1 ; iParam <= $# ; ++iParam )); do
		PID="${!iParam}"
		[[ -z "$PID" ]] && break
		[[ -n "${PID//[0-9]}" ]] && break
		[[ -n "$Line" ]] && echo "$Line"
		Line="$(ps $PSOPTS "$PID" | tail -n +2)"
		[[ $? == 0 ]] && res=0
	done
	if [[ $iParam -le $# ]]; then
		local -i iLog
		[[ $iParam == $# ]] || iLog=1
		Line+=" | logs:"
		while [[ $iParam -le $# ]]; do
			local LogLabel=""
			[[ "$iLog" == 0 ]] || LogLabel+="[${iLog}]"
			LogFile="${!iParam}"
			if [[ -r "$LogFile" ]]; then
				Line+=" ${LogLabel} $(wc -l < "$LogFile")"
			else
				Line+="(${LogLabel} not found);"
			fi
			let ++iParam
			[[ iLog -gt 0 ]] && let ++iLog
		done
	fi
	echo "$Line"
	return $res
} # PrintProcess()


function Report() {
	local Line="$*"
	local OutputFile
	for OutputFile in "${OutputFiles[@]}" ; do
		if [[ -z "$OutputFile" ]]; then
			echo "$Line"
		else
			echo "$Line" >> "$OutputFile"
		fi
	done
} # Report()


function ReportProcess() {
	Report "$(GetDateTag) | $(PrintProcess "$@" )"
} # ReportProcess()


function GetDateTag() {
	printf "%-30s" "$(date)"
}

function isProcessRunning() {
	local PID="$1"
	[[ -z "$PID" ]] && return 1
	[[ -d "/proc/${PID}" ]] && return 0 # Linux
	ps "$PID" >& /dev/null
} # isProcessRunning()

function GetPID() {
	local ProgName="$1"
	
	if [[ -d "/proc/${ProgName}" ]]; then
		echo "$ProgName"
		return 0
	fi
	
	local -a PIDs=( $(pgrep "$ProgName") )
	local -i nPIDs="${#PIDs[@]}"
	local PID=0
	if [[ $nPIDs == 0 ]]; then
		echo "$ProgName"
		return 1
	elif [[ $nPIDs -gt 1 ]]; then
		{
			echo "${nPIDs} processes match '${ProgName}':"
			for PID in "${PIDs[@]}" ; do
				PrintProcess "$PID"
			done
			echo "Monitoring: '${PID}'"
		} >&2
	else
		PID="${PIDs[0]// }"
	fi
	echo "$PID"
	return 0
} # GetPID()


function GetPeakMemory() {
	local PID="$1"
	local VZPeak="$(grep 'VmPeak' "/proc/${PID}/status" | sed -e 's/[^[:digit:]]*\([[:digit:]]\)/\1/g')"
	local RSPeak="$(grep 'VmHWM' "/proc/${PID}/status" | sed -e 's/[^[:digit:]]*\([[:digit:]]\)/\1/g')"
	echo "${VZPeak}"
	echo "${RSPeak}"
	[[ -n "$VZPeak" ]] && [[ -n "$RSPeak" ]]
} # GetPeakMemory()


function Gzip() { gzip -c "$@" ; }	
function Bzip() { bzip2 -c "$@" ; }
function Copy() { cat "$@" ; }


function SaveMemMaps() {
	local PID="$1"
	local MapFile="${2:-"memmap-${PID}.txt"}"
	
	local DateTag="$(date '+%Y%m%d%H%M%S')"
	MapFile="${MapFile//%TIME%/${DateTag}}"
	[[ -r "/proc/${PID}/maps" ]] || return 2
	"$CopyMapProc" "/proc/${PID}/maps" > "$MapFile"
} # SaveMemMaps()


function OnExit() {
	[[ -z "$PID" ]] && return
	local ClosingRemark
	if isProcessRunning "$PID" ; then
		ClosingRemark+="$(GetDateTag) | Process $PID still running"
	else
		ClosingRemark+="$(GetDateTag) | Process $PID has ended"
	fi
	if isFlagSet FindMemPeak ; then
		if [[ -n "$LastRSMemoryPeak" ]]; then
			ClosingRemark+=", memory peak ${LastVZMemoryPeak}, resident ${LastRSMemoryPeak}"
		else
			ClosingRemark+=", memory peak not available"
		fi
	fi
	ClosingRemark+="."
	Report "$ClosingRemark"
} # OnExit()


################################################################################
declare DoHelp=0 DoVersion=0 OnlyPrintEnvironment=0 NoLogDump=0

declare HeaderEvery=25 WaitTime=0
declare -a LogFiles OutputFiles

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
			( '--mempeak' | '--vmpeak' ) FindMemPeak=1 ;;
			( '--every='* )    POLLDELAY="${Param#--*=}" ;;
			( '--wait='* )     WaitTime="${Param#--*=}" ;;
			( '--hdrevery='* ) HeaderEvery="${Param#--*=}" ;;
			( '--cols='* )     Width="${Param#--*=}" ;;
			( '--psopts='* )   PSOPTS="${Param#--*=}" ;;
			( '--memmap' )     MEMMAP="$DEFAULTMAPNAME" ;;
			( '--memmap='* )   MEMMAP="${Param#--*=}" ;;
			( '--logfile='* )  LogFiles=( "${LogFiles[@]}" "${Param#--*=}" ) ;;
			( '--output='* )   OutputFiles=( "${OutputFiles[@]}" "${Param#--*=}" ) ;;
			( '--stdout' )     OutputFiles=( "${OutputFiles[@]}" "" ) ;;
			
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

if isOSX ; then
	isFlagSet FindPeak && FATAL 1 "Memory peak finding not supported in OSX."
	[[ -n "$MEMMAP" ]] && FATAL 1 "Memory map tracking not supported in OSX."
fi

[[ "${#OutputFiles[*]}" == 0 ]] && OutputFiles=( '' )

ProcessSpec="${Processes[0]}"

let WaitTime*=10 # integral count on tenths of seconds
declare -i WaitTimeElapsed=0
while [[ $WaitTimeElapsed -le $WaitTime ]]; do
	PID="$(GetPID "${Processes[0]}")" && break
	[[ $WaitTimeElapsed == 0 ]] && echo "Waiting up to $((WaitTime/10)) s for the process to start."
	sleep 0.1
	let WaitTimeElapsed+=1
done
# if [[ ! "$PID" =~ ^[0-9]+$ ]] || ! isProcessRunning "$PID" ; then
if [[ $WaitTimeElapsed -gt $WaitTime ]] ; then
	echo "$(GetDateTag) - no process ${ProcessSpec} is currently running."
	exit 1
fi

case "$MEMMAP" in
	( '.bz2' | '.gz2' ) MEMMAP="${DEFAULTMAPNAME}${MEMMAP}" ;;
	( * ) ;;
esac
[[ -n "$MEMMAP" ]] && Report "Memory map file name(s): '${MEMMAP}'"
case "$MEMMAP" in
	( *.gz )  CopyMapProc=Gzip ;;
	( *.bz2 ) CopyMapProc=Bzip ;;
	( * )     CopyMapProc=Copy ;;
esac


# build the header line
DateTag="$(GetDateTag)"
HeaderLine="$(printf "%-${#DateTag}s" "Hit <Ctrl>+<C> to exit" | cut -c 1-${#DateTag} ) | $(ps $PSOPTS "$PID" | head -n 1)"
unset DateTag

if [[ "${#LogFiles[@]}" -gt 1 ]]; then
	Report "Monitored logs (${#LogFiles[@]}):"
	for (( iLog = 0 ; iLog < ${#LogFiles[@]} ; ++iLog )); do
		Report " [$((iLog+1))] '${LogFiles[iLog]}'"
	done
fi

# provide some feedback on exit
trap OnExit EXIT

[[ $HeaderEvery -gt 0 ]] && Report "$HeaderLine" | cut -c 1-${Width}

declare LastRSMemoryPeak="" LastVZMemoryPeak="" NewRSMemoryPeak NewVZMemoryPeak
for (( iPolls = 1 ;; ++iPolls )); do
	ReportProcess "$PID" "${LogFiles[@]}" | cut -c 1-${Width}
	[[ -n "$MEMMAP" ]] && SaveMemMaps "$PID" "$MEMMAP"
	if isFlagSet FindMemPeak ; then
		{ read NewVZMemoryPeak ; read NewRSMemoryPeak ; } < <(GetPeakMemory "$PID")
		if [[ -n "$NewRSMemoryPeak" ]]; then
			LastRSMemoryPeak="$NewRSMemoryPeak"
			LastVZMemoryPeak="$NewVZMemoryPeak"
		fi
	fi
	sleep $POLLDELAY
	isProcessRunning "$PID" || break
	if [[ $HeaderEvery -gt 0 ]] && [[ $((iPolls % $HeaderEvery)) == 0 ]]; then
		echo "$HeaderLine" | cut -c 1-${Width}
	fi
done

# OnExit will do the deal here
