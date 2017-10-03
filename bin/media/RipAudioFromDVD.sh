#!/bin/bash
#
# Rips the audio track from all the titles in the DVD.
# One output file is produced per title.
#

SCRIPTNAME="$(basename "$0")"
SCRIPTDIR="$(dirname "$0")"

: ${DEFAULTOUTPUTPATTERN="Title%t.mp3"}
: ${DEFAULTDEV:="/dev/dvd"}

# Output parameters:
: ${SamplingFreq:=44100}
: ${SamplingBits:=16}
: ${SamplingChannels:=2}

: ${AudioChannel:=0}

: ${DEFAULTFORMAT:='mp3'}

###############################################################################
function help() {
	cat <<-EOH
	Creates an audio file for each of the titles in a DVD.

	Usage:  ${SCRIPTNAME}  [options]  [-|--]  OutputFilePattern
	
	The output file pattern is a normal file name.
	By default, the format is deduced from the suffix of the file name.
	The following tags are replaced in the pattern:
	  %t the padded number of the title (e.g. "01")
	  %%  a single percent character
	
	Options:
	--dvd=DEVICE [${DEFAULTDEV}]
	    specifies the device of the DVD
	--from-title=FIRST [1]
	    start ripping from this title (title numbers start from 1)
	--last-title=LAST [last title in DVD]
	    rip up to this title, included (title numbers start from 1)
	--titles=FIRST-LAST
	    equivelent to --from-title=FIRST --last-title=LAST
	--title-offset=OFFSET
	    when using the title number for file names, add this offset to it
	--title-padding=PADDING [autodetect]
	    pad the title number with zeroes in file names to be this many characters wide
	--keep-going , -k
	    in case of error, skips to the next title rather than aborting
	--force , -f
	    if an output file exists, it's overwritten (by default, the title is skipped)
	--dry-run , -n
	    does not run extraction, but writes the command that would be used
	--help , -h , -?
	    prints this help message and exits
	
	EOH
} # help()

###############################################################################
function STDERR() { echo "$*" >&2 ; }

function ERROR() { STDERR "ERROR: $*" ; }
function FATAL() {
	local -i Code="$1"
	shift
	STDERR "FATAL (${Code}): $*"
	exit $Code
} # FATAL()

function LASTFATAL() {
	local Code="$?"
	[[ $Code == 0 ]] && return
	FATAL "$Code" "$@"
} # LASTFATAL()

function isFlagSet() {
	local VarName="$1"
	[[ -n "${!VarName//0}" ]]
} # isFlagSet()

function isFlagUnset() {
	local VarName="$1"
	[[ -z "${!VarName//0}" ]]
} # isFlagUnset()


function ExtractNumberOfTitles() {
	# extracts the number of titles from tcprobe; it expects a line like:
	# [dvd_reader.c] DVD title 1/10: 1 chapter(s), 1 angle(s), title set 1
	local DVDDev="${1:-'/dev/dvd'}"
	tcprobe -i "$DVDDev" 2>&1 | grep 'DVD title' | head | sed -e 's@.*[[:blank:]]DVD title [0-9]\+/\([0-9]\+\):.*@\1@g'
	return ${PIPE_STATUS[0]}
} # ExtractNumberOfTitles()

function CodingOptions() {
	local Format="$1"
	local -a Options
	case "$Format" in
		( 'mp3' )
			Options=( --lame_preset medium )
			;;
		( * )
			FATAL 1 "Output format '${Format}' not supported!"
	esac
	echo "${Options[@]} -E ${SamplingFreq},${SamplingBits},${SamplingChannels}"
} # CodingOptions


###############################################################################
# Argument parsing

declare DVDDev="${DEFAULTDEV}"

declare -i NoMoreOptions=0
declare -a Arguments
declare -i NArguments=0
declare -i KeepGoing=0 Force=0 Fake=0
for (( iParam = 1 ; iParam <= $# ; ++iParam )); do
	Param="${!iParam}"
	if isFlagSet NoMoreOptions || [[ "${Param:0:1}" != '-' ]]; then
		Arguments[NArguments++]="$Param"
	else
		case "$Param" in
			( '--dvd='* )              DVDDev="${Param#*=}" ;;
			( '--from-title='* )       FirstTitle="${Param#*=}" ;;
			( '--last-title='* )       LastTitle="${Param#*=}" ;;
			( '--titles='* )           TitleRange="${Param#*=}" ;;
			( '--title-offset='* )     TitleOffset="${Param#*=}" ;;
			( '--title-padding='* )    TitlePadding="${Param#*=}" ;;
			( '--keep-going' | '-k' )  KeepGoing=1 ;;
			( '--force' | '-f' )       Force=1 ;;
			( '--dry-run' | '-n' )     Fake=1 ;;
			( '--help' | '-h' | '-?' ) DoHelp=1 ;;
			( '--' | '-' )             NoMoreOptions=1 ;;
			( * )
				FATAL 1 "Argument #${iParam} not supported ('${Param}')"
		esac
	fi

done

###############################################################################

if isFlagSet DoHelp ; then
	help
	exit 0
fi

case ${#Arguments[@]} in
	( 0 ) OutputPattern="$DEFAULTOUTPUTPATTERN" ;;
	( 1 ) OutputPattern="${Arguments[0]}" ;;
	( * ) FATAL 1 "Unexpected arguments - ${Arguments[1]} ..."
esac




###############################################################################
# detect the number of titles
declare -i NTitles

NTitles="$(ExtractNumberOfTitles "$DVDDev")"
res=$?
if [[ $res != 0 ]]; then
	echo "Error (${res}) extracting the number of titles from DVD device '${DVDDev}'."
	exit $res
fi
echo "DVD (${DVDDev}) has ${NTitles} titles."

#
# prepare requested title range
#

if [[ -n "$TitleRange" ]]; then
	if [[ "${TitleRange:0:1}" == '-' ]]; then
		LastTitle=${TitleRange#-}
	elif [[ "${TitleRange: -1:1}" == '-' ]]; then
		FirstTitle=${TitleRange%-}
	elif [[ "$TitleRange" =~ ([0-9]+)-([0-9]+) ]]; then
		FirstTitle=${BASH_REMATCH[1]}
		LastTitle=${BASH_REMATCH[2]}
	else
		FATAL 1 "Format for the --titles option not recognized."
	fi
fi


#
# prepare output mask
#
declare BaseName=${OutputPattern%.*}
declare Suffix="${OutputPattern#${BaseName}}"


if [[ ! "$BaseName" =~ %t ]]; then
	BaseName="$(basename "$BaseName")_Title"
fi

declare Format="${Suffix#.}"
[[ -z "$Format" ]] && Format="$DEFAULTFORMAT"

: ${TitleOffset:=0}
declare -i MaxTitle=$(( TitleOffset + NTitles ))
: ${TitlePadding:=${#MaxTitle}}

#
# prepare conversion
#
Options=$(CodingOptions "$Format")
LASTFATAL "error while setting coding options for format '${Format}'"

[[ -z "$FirstTitle" ]] && FirstTitle=1
[[ -z "$LastTitle" ]] && LastTitle="$NTitles"

for (( iTitle = $FirstTitle ; iTitle <= $LastTitle ; ++iTitle )); do
	#  echo transcode -x null,dvd -y null,tcaud -i "$DVDDEV" -T "${iTitle},-1" -a 0 -E "${SamplingFreq},${SamplingBits},${SamplingChannels}" --lame_preset medium -m "$OutputFile"
	PaddedTitleNo="$(printf '%0*d' $TitlePadding $iTitle )"
	LabelTitleNo="$(printf '%0*d' $TitlePadding $((TitleOffset + iTitle)) )"
	OutputFile="${BaseName//%t/${LabelTitleNo}}${Suffix}"
	if [[ -r "$OutputFile" ]] && isFlagUnset Overwrite ; then
		echo "File '${OutputFile}' already exists. Skipping title ${iTitle}."
		continue
	fi
	echo "[${PaddedTitleNo}/${NTitles}] '${OutputFile}'"

	Command=( transcode -x null,dvd -y null,tcaud -i "$DVDDev" -T "${iTitle},-1" -a "$AudioChannel" $Options -m "$OutputFile" )
	if isFlagSet Fake ; then
		echo "DRYRUN> ${Command[@]}"
	else
		"${Command[@]}"
	fi
	res=$?
	if [[ $res != 0 ]]; then
		if isFlagSet KeepGoing ; then
			ERROR "while extracting audio from title ${iTitle} (code: ${res}); continuing..."
			rm -f "$OutputFile"
		else
			FATAL "$res" "while extracting audio from title ${iTitle}."
		fi
	fi

done

