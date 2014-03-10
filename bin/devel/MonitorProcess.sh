#!/bin/sh

SCRIPTNAME="$(basename "$0")"

: ${POLLDELAY:="60"}
: ${COLUMNS:=80}
: ${PSOPTS:="-o user,pid,ppid,stat,psr,pcpu,pmem,sz,rss,vsz,stime,etime,cputime,tt"}

function help() {
	cat <<-EOH
	Continuously prints information about a process.
	
	Usage:  ${SCRIPTNAME}  PID
	
	Variables:
	POLLDELAY ['${POLLDELAY}']
	    polling period in seconds
	COLUMNS ['${COLUMNS}']
	    the number of columnson the screen (autodetection seems to fail...)
	PSOPTS ['${PSOPTS}']
	    the ps program options to be used
	
	EOH
} # help


function PrintProcess() {
	local PID
	local res=1
	for PID in "$@" ; do
		ps --no-header $PSOPTS "$PID"
		[[ $? == 0 ]] && res=0
	done
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
	
	local -a PIDs="$(ps --no-header -o %p -C "$ProgName")"
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


if [[ -z "$1" ]] || [[ "$1" == "-h" ]] || [[ "$1" == "-?" ]] || [[ "$1" == "--help" ]]; then
	help
	exit
fi

ProcessSpec="$1"
PID="$(GetPID "$1")"

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
	if [[ $((iPolls % 25)) == 0 ]]; then
		echo "$HeaderLine" | cut -c 1-${COLUMNS}
	fi
	echo "$(GetDateTag) | $(PrintProcess "$PID" )" | cut -c 1-${COLUMNS}
	sleep $POLLDELAY
done
echo "$(GetDateTag) | Process $PID has ended."
