#!/bin/sh

SCRIPTNAME="$(basename "$0")"


function isFlagSet() {
	local VarName="$1"
	[[ -n "${!VarName//0}" ]]
} # isFlagSet

function STDERR() {
	echo "$*" >&2
} # STDERR

function ERROR() {
	STDERR "ERROR: $*"
} # ERROR

function help() {
	cat <<-EOH
	Prints the command corresponding to the specified PIDs.
	
	Usage:  ${SCRIPTNAME} [Options] PID [ [Options] PID ...]
	
	Options affect only the following PIDs.
	
	Available options:
	-c --workdir
	    prints the working directory where the process was started
	-C --noworkdir
	    negates the previous option (default)
	-p --pid
	    prints the PID at the beginning of the line
	-P --nopid
	    negates the previous option (default)
	EOH
} # help

function isNumber() {
	local Value="$1"
	[[ -z "${Value//[0-9]}" ]]
} # isNumber()

if [[ $# == 0 ]]; then
	help
	exit
fi

WDMode=0
PrintPID=0

for PIDspec in "$@" ; do
	if [[ "${PIDspec:0:1}" == '-' ]]; then
		case "$PIDspec" in
			( '-c' | '--workdir' )
				WDMode=1
				;;
			( '-C' | '--noworkdir' )
				WDMode=0
				;;
			( '-p' | '--pid' )
				PrintPID=1
				;;
			( '-P' | '--nopid' )
				PrintPID=0
				;;
			( '-h' | '--help' | '-?' )
				DoHelp=1
				;;
			( * )
				ERROR "Option '${PIDspec}' ignored."
				continue
				;;
		esac
		continue
	fi
	
	if isFlagSet DoHelp ; then
		help
		exit 1
	fi

	declare -i nPIDs=0
	declare -a PIDs
	
	if isNumber "$PIDspec" ; then
		PIDs[nPIDs++]="$PIDspec"
	else
		for PID in $(ps -C "$PIDspec" --no-header -o '%p' 2> /dev/null) ; do
			PIDs[nPIDs++]="$PID"
		done
	fi
	
	for PID in "${PIDs[@]}" ; do
		ProcDir="/proc/${PID}"
		if [[ ! -d "$ProcDir" ]]; then
			ERROR "No process '${PID}' running."
			continue
		fi
		
		if isFlagSet PrintPID ; then
			printf '%10d: ' "$PID"
		fi
		
	#	PIDCWD="$(readlink "${ProcDir}/cwd" 2> /dev/null)"
		if isFlagSet WDMode ; then
			PIDWD="$(tr '\0' '\n' < "${ProcDir}/environ" | grep '^PWD=' | sed -e 's/^PWD=//' 2> /dev/null)"
			if [[ -n "$PIDWD" ]]; then
				echo -n "${PIDWD}\$ "
			else
				echo -n "<unknown directory>\$ "
			fi
		fi
		
		CmdLineFile="${ProcDir}/cmdline"
		if [[ -r "$CmdLineFile" ]]; then
			tr '\0' ' ' < "$CmdLineFile"
		else
			echo -n " command line for process $PID not accessible"
		fi
		echo
	done
done

