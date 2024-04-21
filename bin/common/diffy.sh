#!/usr/bin/env bash

SCRIPTNAME="$(basename "$0")"
SCRIPTDIR="$(dirname "$0")"

: ${WIDTH:="$(sed -e 's/^diffy\([0-9]*\).sh$/\1/' <<< "$SCRIPTNAME" )"}

function GetColumns() {
	# `stty --all` produces an output like:
	# speed 38400 baud; rows 78; columns 281; line = 0;
	# intr = ^C; quit = ^\; erase = ^?; kill = ^U; eof = ^D; [...]
	stty --all | tr ';' '\n' | grep 'columns' | awk '{ print $2 ; }'
}

[[ "$WIDTH" == "$SCRIPTNAME" ]] && WIDTH=""
if [[ -z "$WIDTH" ]]; then
	[[ -z "$COLUMNS" ]] && COLUMNS="$(GetColumns)"
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


function isDebugging() {
	local -i Level="${1:-1}"
	isFlagSet DEBUG && [[ "$Level" -le "$DEBUG" ]]
} # isDebugging()

function DBGN() {
	local -i Level="$1"
	shift
	isDebugging "$Level" && STDERR "DBG[${Level}]| $*"
} # DBGN()

function DBG() { DBGN 1 "$@" ; }


function UncompressInput() {
	local FileName="$1"
	local -a UncompressCmd
	case "${FileName##*.}" in
		( 'bz2' ) UncompressCmd=( 'bzcat' ) ;;
		( 'gz' )  UncompressCmd=( 'zcat' ) ;;
		( * )     UncompressCmd=( 'cat' ) ;;
	esac
	if isDebugging 2 ; then
		DBGN 2 "Uncompressing input with '${UncompressCmd[@]} ${FileName}'"
	else
		DBGN 1 "Uncompressing input with '${UncompressCmd[0]}': '${FileName}'"
	fi
	"${UncompressCmd[@]}" "$FileName"
} # UncompressInput()


function ApplyFilters() {
	local HeadLines="$1"
	shift
	local -a Filters=( "$@" )
	if isFlagSet HeadLines ; then
		DBGN 2 "Piping filter head on input..."
		Filters+=( head -n "$HeadLines" )
	fi
	[[ ${#Filters[@]} == 0 ]] && Filters=( 'cat' )
	local FilterString="$( printf '%s |' "${Filters[@]}" )"
	FilterString="${FilterString% |}" # remove the last piping
	DBGN 1 "Filtering input with: '${FilterString}'"
	eval -- "$FilterString"
} # ApplyFilters()


function ProcessInput() {
	local FileName="$1"
	DBG "Processing input: '${FileName}'"
	UncompressInput "$FileName" | ApplyFilters "$HeadLines" "${InputFilters[@]}"
} # ProcessInput()


function PrintHelp() {
	cat <<-EOH
	Compares two files side by side.
	
	Usage:  ${SCRIPTNAME}  [options] firstFile secondFile
	
	Options:
	--width=WIDTH [default: autodetect]
	    sets the total length of the lines in the output.
	--head=N
	    only compares the first N lines of each file.
	--filter="command"
	    applies a filter to each file before comparing them. For example, to
	    exclude all the lines that start with a "#" from the comparison, the
	    option \`--filter="grep -v -E '#' "\` can be specified, and to exclude
	    also the empty lines a second filter \`--filter="grep -v -E '^$'\`can
	    follow. Note that the quotation of these filter commands is not trivial.
	    These filters are run via Bash command \`eval\`.
	--debug[=LEVEL]
	    enables debug messages up to LEVEL, included. If LEVEL is omitted, it's
	    set to 1.
	--help, -h, -?
	    prints this message and exits.
	EOH
}

declare -i DEBUG
declare -i nOptions=0
declare -a Options
declare -i HeadLines=0
declare -i nInputs=0
declare -a Inputs
declare -a InputFilters
declare -i NoMoreOptions=0
for (( iParam = 1 ; iParam <= $# ; ++iParam )); do
	Param="${!iParam}"
	
	if isFlagSet NoMoreOptions || [[ "${Param:0:1}" != '-' ]] && [[ -r "$Param" ]] ; then
		Inputs[nInputs++]="$Param"
	else
		case "$Param" in
			( '--width='* ) WIDTH="${Param#--*=}" ;;
			( '--head='* )  HeadLines="${Param#--*=}" ;;
			( '--filter='* ) InputFilters+=( "${Param#--filter=}" ) ;;
			( '--debug='* ) DEBUG="${Param#--*=}" ;;
			( '--debug' )   DEBUG=1 ;;
			( '--help' | '-h' | '-?' ) DoHelp=1 ;;
			( '-' | '--' )
				NoMoreOptions=1
				;;& # continue toward the default pattern
			( * )
				Options[nOptions++]="$Param"
		esac
	fi
done

export DEBUG
if isFlagSet DoHelp ; then
	PrintHelp
	exit 0
fi

[[ $nInputs == 2 ]] || FATAL 1 "Exactly two input files must be specified -- found ${nInputs}."

DBG "Base command:  diff -y ${WIDTH:+-W "${WIDTH}"} -b \"${Options[@]}\" \<( ProcessInput \"${Inputs[0]}\" ) \<( ProcessInput \"${Inputs[1]}\" ) | less -SRMr -x 8"
diff -y ${WIDTH:+-W ${WIDTH}} -b "${Options[@]}" <( ProcessInput "${Inputs[0]}" ) <( ProcessInput "${Inputs[1]}" ) | less -SRMr -x 8

