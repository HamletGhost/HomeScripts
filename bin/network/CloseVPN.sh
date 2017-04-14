#!/bin/bash

declare SelectedPIDFile="$1"

declare PIDFilePrefix='/var/run/openconnect'

declare DefaultServer='vpn.fnal.gov'
declare DefaultVPNUser='petrillo@services.fnal.gov'
declare DefaultPIDFile="${PIDFilePrefix}-${DefaultVPNUser}-${DefaultServer}.pid"

declare -a PIDFiles
readarray -t PIDFiles < <( ls "$PIDFilePrefix"*.pid )
declare -i NPIDFiles="${#PIDFiles[@]}"

case "$NPIDFiles" in
	( 0 )
		echo "No openconnect process ID found." >&2
		exit 1
		;;
	( 1 )
		PIDFile="${PIDFiles[0]}"
		;;
	( * )
		# if we have a selection, just use it
		if [[ -n "$SelectedPIDFile" ]]; then
			if [[ "$SelectedPIDFile" -lt "$NPIDFiles" ]]; then
				PIDFile="${PIDFiles[$SelectedPIDFile]}"
			else
				echo "Invalid request of PID file #${SelectedPIDfile} -- only ${NPIDFiles} are available." >&2
				exit 1
			fi
		fi
		# if the default PID file is present, use that one.
		# Otherwise, just complain.
		declare File
		for File in "${PIDFiles[@]}" '' ; do
			[[ "$File" == "$DefaultPIDFile" ]] && break
		done
		if [[ -n "$File" ]]; then
			PIDFile="$DefaultPIDFile"
		else
			echo "Multiple openconnect PIDs found. Close one with \"${0} #\", where # is:"
			declare -i iFile
			declare -i MaxFileIndex=$((NPIDFiles - 1))
			declare -i Padding="${#MaxFileIndex}"
			for (( iFile=0 ; iFile < $NPIDFiles ; ++iFile )); do
				File="${PIDFiles[iFile]}"
				printf '%*d  "%s" (PID=%d)\n' "$Padding" "$iFile" "$File" "$(< "$File" )"
			done
			exit 1
		fi
		;;
esac

declare -i PID
PID=$(< "$PIDFile" )
if [[ $? != 0 ]]; then
	echo "Unexpected content in PID file '${PIDFile}'. No action taken." >&2
	exit 1
fi

# sending SIGINT, that tells openconnect to close the connection and exit.
echo "Terminating the openconnect session with PID=${PID} (from '${PIDFile}')."
kill -INT "$PID"

