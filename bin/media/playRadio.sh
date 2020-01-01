#!/usr/bin/env bash

SCRIPTNAME="$(basename "$0")"
SCRIPTDIR="$(dirname "$0")"
SCRIPTVERSION="1.0"


# ------------------------------------------------------------------------------
# ---  program default settings
# ------------------------------------------------------------------------------
: ${mplayer:="mplayer"}
declare -a DefaultRadioDirs=( "${HOME}/media/music/radio" )


# ------------------------------------------------------------------------------
# import function library

declare -r FunctionLibRelPath="common/functions.sh"
for Dir in "$SCRIPTDIR" "${SCRIPTDIR}/.." '' ; do
  FunctionLibPath="${Dir%/}/${FunctionLibRelPath}"
  [[ -r "$FunctionLibPath" ]] || continue
  source "$FunctionLibPath"
  break
done
[[ -n "$Dir" ]] || { echo "Can't find function library." >&2 ; exit 2 ; }
SetColors
DBG "Function library loaded: '${FunctionLibPath}'"


# ------------------------------------------------------------------------------
# ---  functions
# ------------------------------------------------------------------------------
function PrintHelp() {
  cat <<-EOH

Plays a streamed radio.

Usage:  ${SCRIPTNAME}  [options]  RadioName

Radio settings are stored in directory ${RadioDirs[@]} (see \`--radiodir\`) as
files in the form:
  - \`<RadioName>.url\`: the file contains a URL to be directly streamed
  - \`<RadioName>.playlisturl\`: the file contains a URL to a play list

Options:
--radiodir=RADIODIR
    specifies where to find the radio information; can be specified multiple
    times
--list , -l
    prints all the radio information files found
--fake , --dryrun , -n
    does not play music but prints the command it would run
--verbose , -v
    prints additional messages on screen
--debug , -d, --debug[=LEVEL]
    enables debugging messages (if not specified, LEVEL defaults to \`1\`)
--version , -V
    prints the script version (i.e. '${SCRIPTVERSION}')
--help , -h , -?
    prints these usage instructions

EOH
} # PrintHelp()


function PrintVersion() {
  INFO "${SCRIPTNAME} version ${SCRIPTVERSION}."
} # PrintVersion()


# ------------------------------------------------------------------------------
function Exec() {
  local -a Cmd=( "$@" )
  
  if isFlagSet Fake || isFlagSet Verbose ; then
    INFO "CMD> ${Cmd[@]}"
  else
    DBG "CMD> ${Cmd[@]}"
  fi
  isFlagSet Fake || "${Cmd[@]}"

} # Exec()

# ------------------------------------------------------------------------------
function PrintList() {
  local RadioDir
  for RadioDir in "${RadioDirs[@]}" ; do
    [[ -n "$RadioDir" ]] && pushd "$RadioDir" > /dev/null
    
    INFO "Radio information files present in '${RadioDir:-$(pwd)}':"
    ls | sort
    
    [[ -n "$RadioDir" ]] && popd > /dev/null
  done
} # PrintList()


function FindRadioInfo() {
  local RadioName="$1"
  
  local -a Candidates
  local RadioDir
  for RadioDir in "${RadioDirs[@]}" ; do
    local BasePattern="${RadioDir:+${RadioDir%/}/}${RadioName}"
    DBGN 2 "Looking for radio information files matching '${BasePattern}'"
    readarray -t -O "${#Candidates[@]}" Candidates < <( ls "$BasePattern"* 2> /dev/null )
  done
  
  local -i NCandidates=${#Candidates[@]}
  DBGN 2 "Found ${NCandidates} candidates."
  
  if [[ $NCandidates -gt 1 ]]; then
    ERROR "Multiple candidates found:"
    local Candidate
    for Candidate in "${Candidates[@]}" ; do
      ERROR " - '${Candidate}'"
    done
    FATAL 1 "Found ${NCandidates} radio matching the name '${RadioName}'."
  fi
  
  echo "${Candidates[0]}"
  return 0
} # FindRadioInfo()


# ------------------------------------------------------------------------------
function CheckRadioInfoDirectories() {
  
  local RadioDir
  local -a VerifiedRadioDirs
  for RadioDir in "${RadioDirs[@]}" ; do
    if [[ -d "$RadioDir" ]]; then
      DBGN 2 "Radio information directory '${RadioDir}' verified."
      VerifiedRadioDirs+=( "$RadioDir" )
    else
      WARN "The radio information directory '${RadioDir}' does not exits (fix with option \`--radiodir\`)."
    fi
  done
  RadioDirs=( "${VerifiedRadioDirs[@]}" )
  [[ "${#RadioDirs[@]}" == 0 ]] && FATAL 1 "No valid radio information directories are specified!"

} # CheckRadioInfoDirectories()


# ------------------------------------------------------------------------------
function PlayDispatcher() {
  local RadioInfoPath="$1"
  
  local RadioInfoName="$(basename "$RadioInfoPath")"
  local RadioInfoType="${RadioInfoName##*.}"
  
  local PlayerFunction="play_${RadioInfoType}"
  
  declare -f "$PlayerFunction" >& /dev/null || FATAL 1 "Information format '${RadioInfoType}' not supported."
  
  DBGN 2 "Running '${PlayerFunction}'"
  "$PlayerFunction" "$RadioInfoPath"
  
} # PlayDispatcher()


# ------------------------------------------------------------------------------
function play_url {
  local RadioInfoFile="$1"
  
  local URL="$(< "$RadioInfoFile" )"
  
  Exec $mplayer "$URL"
  
} # play_url()


# ------------------------------------------------------------------------------
function play_playlisturl {
  local RadioInfoFile="$1"
  
  local URL="$(< "$RadioInfoFile" )"
  
  Exec $mplayer "${mplayerOptions[@]}" '-playlist' "$URL"
  
} # play_url()


# ------------------------------------------------------------------------------
# --- main program
# ------------------------------------------------------------------------------
#
# parameter parser
#

declare -i NoMoreOptions=0
declare -i DoHelp=0 DoVersion=0 DoList=0 Verbose=0 False=0
declare -i iParam
declare -i ErrorCode=0
declare -a RadioDirs
for (( iParam = 1 ; iParam <= $# ; ++iParam )); do
  Param="${!iParam}"
  
  DBGN 2 "Processing argument #${iParam} ('${Param}')"
  if isFlagUnset NoMoreOptions && [[ "${Param:0:1}" == '-' ]]; then
  
    case "$Param" in
      ( '--radiodir='* )  RadioDirs+=( "${Param#--*=}" );;
      ( '--list' | '-l' ) DoList=1 ;;
      
      ( '--verbose' | '-V' )           Verbose=1 ;;
      ( '--debug' | '-d' )             DEBUG=1 ;;
      ( '--debug='* )                  DEBUG="${Param#--*=}" ;;
      ( '--fake' | '--dryrun' | '-n' ) Fake=1 ;;
      
      ( '--version' | '-V' )     DoVersion=1 ;;
      ( '--help' | '-h' | '-?' ) DoHelp=1 ;;
      
      ( '--' | '-' ) NoMoreOptions=1 ;;
      
      ( * )
        CRITICAL 1 "Unsupported argument #${iParam} -- '${Param}'"
        ErrorCode=$?
        ;;
    esac
  
  else
    if [[ -n "$RadioName" ]]; then
      CRITICAL 1 "Radio name specified more than once ('${RadioName}', then '${Param}')."
      ErrorCode=$?
    else
      RadioName="$Param"
    fi
  fi
  
done

[[ "${#RadioDirs[@]}" == 0 ]] && RadioDirs=( "${DefaultRadioDirs[@]}" )

if isFlagSet DoVersion; then
  InfoRunCode=0
  PrintVersion
fi
if isFlagSet DoHelp ; then
  InfoRunCode=0
  PrintHelp
fi
if isFlagSet DoList ; then
  InfoRunCode=0
  PrintList
fi

if isFlagSet ErrorCode && isFlagUnset DoHelp; then
  PrintHelp
  exit $ErrorCode
fi

[[ -n "$InfoRunCode" ]] && exit "$InfoRunCode"

# ------------------------------------------------------------------------------
#
# information retrieval
#
CheckRadioInfoDirectories

declare RadioInfoPath="$(FindRadioInfo "$RadioName")"
[[ -r "$RadioInfoPath" ]] || FATAL 2 "Information for radio '${RadioName}' not found."
DBG "Information for radio '${RadioName}' found at '${RadioInfoPath}'."

#
# start playing
#
PlayDispatcher "$RadioInfoPath"

# all done
# ------------------------------------------------------------------------------
