#!/usr/bin/env bash
#
# Prints the window name and index for specified pseudoterminals.
#
# Usage:  FindTmuxTTY.sh [terminal [terminal ...]]
# 
#

: ${tmux:="$(which tmux)"}

function ListWindows() {
	$tmux list-windows -F "#{pane_tty} #{window_index} #{window_name}"
} # ListWindows()

function matchesAny() {
	# isInList Item [Key Key ...]
	local Item="$1"
	shift
	local -a Keys=( "$@" )
	local Key
	for Key in "${Keys[@]}" ; do
		[[ "$Item" =~ ${Key}$ ]] && return 0
	done
	return 1
} # matchesAny()

function FilterOutput() {
	local -a Keys=( "$@" )
	local -i DoFilter
	[[ "${#Keys[@]}" == 0 ]] || DoFilter=1
	local tty window_index window_name
	local -i Matches=0
	while read tty window_index window_name ; do
		if [[ -z "$DoFilter" ]] || matchesAny "${tty#/dev/}" "${Keys[@]}" ; then
			printf '%-15s - #%02d  "%s"\n' "${tty#/dev/}" "$window_index" "$window_name"
			let ++Matches
		fi
	done
	[[ $Matches -gt 0 ]]
} # FilterOutput()


declare -a Specs
for Spec in "$@" ; do
	[[ "$Spec" =~ / ]] || Spec="pts/${Spec}"
	Specs+=( "$Spec" )
done

ListWindows | FilterOutput "${Specs[@]}"

