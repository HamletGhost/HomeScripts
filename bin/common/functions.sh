#!/bin/bash
#
# Provides some common functions and definition.
# Source it in your script.
#
# All debug output in this library has a level of at least 10.
#

if [[ -z "$FUNCTIONS_SH_LOADED" ]]; then
	
	# some ANSI terminal color codes
	export ANSIRESET="\e[0m"
	export ANSIRED="\e[1;31m"
	export ANSIGREEN="\e[0;32m"
	export ANSIYELLOW="\e[1;33m"
	export ANSICYAN="\e[36m"
	export ANSIGRAY="\e[1;30m"
	export ANSIWHITE="\e[1;37m"
	
	
	export FUNCTIONS_SH_LOADED="${BASH_SOURCE[0]}"
	
fi # if functions were not loaded

###
### Basic utilities on variables
###
function isFunctionSet() {
	local FunctionName="$1"
	declare -F "$FunctionName" >& /dev/null
} # isFunctionSet()

function isNameSet() {
	local Name="$1"
	declare -p "$Name" >& /dev/null
} # isNameSet()

function isVariableSet() {
	local Name="$1"
	isNameSet "$Name" && ! isFunctionSet "$Name"
} # isVariableSet()

function isFlagSet() {
	local VarName="$1"
	[[ -n "${!VarName//0}" ]]
} # isFlagSet()

function isFlagUnset() {
	local VarName="$1"
	[[ -z "${!VarName//0}" ]]
} # isFlagUnset()

function ifFlagSet() {
	# ifFlagSet FLAGNAME TrueString [FalseString]
	# 
	# Prints <TrueString> if FLAGNAME is set, <FalseString> otherwise (which by
	# default it is empty, in which case nothing is printed).
	#
	local -r FlagName="$1"
	local -r TrueString="$2"
	local -r FalseString="$3"
	
	if isFlagSet "$FlagName" ; then
		echo "$TrueString"
		true # for the return value
	else
		[[ $# -ge 3 ]] && echo "$FalseString"
		false # for the return value
	fi
} # ifFlagSet()

function ifFlagUnset() {
	# ifFlagUnset FLAGNAME TrueString [FalseString]
	# 
	# Prints <TrueString> if FLAGNAME is set, <FalseString> otherwise (which by
	# default it is empty, in which case nothing is printed).
	#
	local -r FlagName="$1"
	local -r TrueString="$2"
	local -r FalseString="$3"
	
	if isFlagUnset "$FlagName" ; then
		echo "$TrueString"
		true # for the return value
	else
		[[ $# -ge 3 ]] && echo "$FalseString"
		false # for the return value
	fi
} # ifFlagUnset()



###
###  basic utilities on lists
###
function isSameList() {
  #
  # isSameList NItems FirstItems... SecondItems...
  # 
  # Returns success if the second list have the same cardinality (`NItems`)
  # as the first one, and if their elements match their values.
  #
  local -i NFirst="$1"
  shift
  
  local -i n="$NFirst"
  [[ $# -eq $((2 * n)) ]] || return 1
  
  local -a First
  while [[ $NFirst -gt 0 ]]; do
    First+=( "$1" )
    let --NFirst
    shift
  done
  local -a Second=( "$@" )
  for (( i = 0 ; i < n ; ++i )); do
    [[ "${First[i]}" == "${Second[i]}" ]] || return 1
    
  done
  return 0
} # isSameList()


function FindInList() {
  #
  # FindInList Key [Item...]
  #
  # Prints the index of the first value Key in the list of Item elements,
  # and return non-zero exit code if not present
  #
  
  local Key="$1"
  shift
  local -i i=0
  local Item
  for Item in "$@" ; do
    [[ "$Key" == "$Item" ]] && echo "$i" && return 0
    let ++i
  done
  return 1
} # FindInList()


function TestFindInList() {
  
  declare -a List=( 'a' 'b' 'c' 'b' 'd' 'd' '' 'e' )
  declare -a cmd
  local res exp ret
  local -i nErrors=0
  
  cmd=( FindInList 'a' "${List[@]}" )
  exp=0
  [[ -n "$exp" ]]
  expRet=$?
  res="$( "${cmd[@]}" )"
  ret=$?
  if [[ "$res" != "$exp" ]] || [[ "$ret" != "$expRet" ]]; then
    let ++nErrors
    ERROR "\`${cmd[@]}\` => '${res}' [return: ${ret}] ('${exp}' and ${expRet} expected)"
  fi
  
  cmd=( FindInList 'b' "${List[@]}" )
  exp=1
  [[ -n "$exp" ]]
  expRet=$?
  res="$( "${cmd[@]}" )"
  ret=$?
  if [[ "$res" != "$exp" ]] || [[ "$ret" != "$expRet" ]]; then
    let ++nErrors
    ERROR "\`${cmd[@]}\` => '${res}' [return: ${ret}] ('${exp}' and ${expRet} expected)"
  fi
  
  cmd=( FindInList 'c' "${List[@]}" )
  exp=2
  [[ -n "$exp" ]]
  expRet=$?
  res="$( "${cmd[@]}" )"
  ret=$?
  if [[ "$res" != "$exp" ]] || [[ "$ret" != "$expRet" ]]; then
    let ++nErrors
    ERROR "\`${cmd[@]}\` => '${res}' [return: ${ret}] ('${exp}' and ${expRet} expected)"
  fi
  
  cmd=( FindInList 'd' "${List[@]}" )
  exp=4
  [[ -n "$exp" ]]
  expRet=$?
  res="$( "${cmd[@]}" )"
  ret=$?
  if [[ "$res" != "$exp" ]] || [[ "$ret" != "$expRet" ]]; then
    let ++nErrors
    ERROR "\`${cmd[@]}\` => '${res}' [return: ${ret}] ('${exp}' and ${expRet} expected)"
  fi
  
  cmd=( FindInList 'e' "${List[@]}" )
  exp=7
  [[ -n "$exp" ]]
  expRet=$?
  res="$( "${cmd[@]}" )"
  ret=$?
  if [[ "$res" != "$exp" ]] || [[ "$ret" != "$expRet" ]]; then
    let ++nErrors
    ERROR "\`${cmd[@]}\` => '${res}' [return: ${ret}] ('${exp}' and ${expRet} expected)"
  fi
  
  cmd=( FindInList 'f' "${List[@]}" )
  exp=""
  [[ -n "$exp" ]]
  expRet=$?
  res="$( "${cmd[@]}" )"
  ret=$?
  if [[ "$res" != "$exp" ]] || [[ "$ret" != "$expRet" ]]; then
    let ++nErrors
    ERROR "\`${cmd[@]}\` => '${res}' [return: ${ret}] ('${exp}' and ${expRet} expected)"
  fi
  
  cmd=( FindInList '' "${List[@]}" )
  exp=6
  [[ -n "$exp" ]]
  expRet=$?
  res="$( "${cmd[@]}" )"
  ret=$?
  if [[ "$res" != "$exp" ]] || [[ "$ret" != "$expRet" ]]; then
    let ++nErrors
    ERROR "\`${cmd[@]}\` => '${res}' [return: ${ret}] ('${exp}' and ${expRet} expected)"
  fi
  
  
  #
  # all tests done
  #
  if [[ $nErrors -gt 0 ]]; then
    declare -p List
    ERROR "${FUNCNAME}: ${nErrors} tests failed."
  fi
  
  return $nErrors
} # TestFindInList()


function FindLastInList() {
  #
  # FindLastInList Key [Item...]
  #
  # Prints the index of the last value Key in the list of Item elements,
  # and return non-zero exit code if not present
  #
  
  local Key="$1"
  shift
  local -i i=$#
  local Item
  while [[ $i -gt 0 ]]; do
    Item="${!i}" # remember that positional parameter indices start from 1
    let --i
    [[ "$Key" == "$Item" ]] && echo "$i" && return 0
  done
  return 1
} # FindLastInList()


function TestFindLastInList() {
  
  declare -a List=( 'a' 'b' 'c' 'b' 'd' 'd' '' 'e' )
  declare -a cmd
  local res exp ret
  local -i nErrors=0
  
  cmd=( FindLastInList 'a' "${List[@]}" )
  exp=0
  [[ -n "$exp" ]]
  expRet=$?
  res="$( "${cmd[@]}" )"
  ret=$?
  if [[ "$res" != "$exp" ]] || [[ "$ret" != "$expRet" ]]; then
    let ++nErrors
    ERROR "\`${cmd[@]}\` => '${res}' [return: ${ret}] ('${exp}' and ${expRet} expected)"
  fi
  
  cmd=( FindLastInList 'b' "${List[@]}" )
  exp=3
  [[ -n "$exp" ]]
  expRet=$?
  res="$( "${cmd[@]}" )"
  ret=$?
  if [[ "$res" != "$exp" ]] || [[ "$ret" != "$expRet" ]]; then
    let ++nErrors
    ERROR "\`${cmd[@]}\` => '${res}' [return: ${ret}] ('${exp}' and ${expRet} expected)"
  fi
  
  cmd=( FindLastInList 'c' "${List[@]}" )
  exp=2
  [[ -n "$exp" ]]
  expRet=$?
  res="$( "${cmd[@]}" )"
  ret=$?
  if [[ "$res" != "$exp" ]] || [[ "$ret" != "$expRet" ]]; then
    let ++nErrors
    ERROR "\`${cmd[@]}\` => '${res}' [return: ${ret}] ('${exp}' and ${expRet} expected)"
  fi
  
  cmd=( FindLastInList 'd' "${List[@]}" )
  exp=5
  [[ -n "$exp" ]]
  expRet=$?
  res="$( "${cmd[@]}" )"
  ret=$?
  if [[ "$res" != "$exp" ]] || [[ "$ret" != "$expRet" ]]; then
    let ++nErrors
    ERROR "\`${cmd[@]}\` => '${res}' [return: ${ret}] ('${exp}' and ${expRet} expected)"
  fi
  
  cmd=( FindLastInList 'e' "${List[@]}" )
  exp=7
  [[ -n "$exp" ]]
  expRet=$?
  res="$( "${cmd[@]}" )"
  ret=$?
  if [[ "$res" != "$exp" ]] || [[ "$ret" != "$expRet" ]]; then
    let ++nErrors
    ERROR "\`${cmd[@]}\` => '${res}' [return: ${ret}] ('${exp}' and ${expRet} expected)"
  fi
  
  cmd=( FindLastInList 'f' "${List[@]}" )
  exp=""
  [[ -n "$exp" ]]
  expRet=$?
  res="$( "${cmd[@]}" )"
  ret=$?
  if [[ "$res" != "$exp" ]] || [[ "$ret" != "$expRet" ]]; then
    let ++nErrors
    ERROR "\`${cmd[@]}\` => '${res}' [return: ${ret}] ('${exp}' and ${expRet} expected)"
  fi
  
  cmd=( FindLastInList '' "${List[@]}" )
  exp=6
  [[ -n "$exp" ]]
  expRet=$?
  res="$( "${cmd[@]}" )"
  ret=$?
  if [[ "$res" != "$exp" ]] || [[ "$ret" != "$expRet" ]]; then
    let ++nErrors
    ERROR "\`${cmd[@]}\` => '${res}' [return: ${ret}] ('${exp}' and ${expRet} expected)"
  fi
  
  
  #
  # all tests done
  #
  if [[ $nErrors -gt 0 ]]; then
    declare -p List
    ERROR "${FUNCNAME}: ${nErrors} tests failed."
  fi
  
  return $nErrors
} # TestFindLastInList()


function isInList() {
  #
  # isInList Key [Item...]
  #
  # Returns 0 exit code if a value Key is in the list of Item elements, non-zero
  # otherwise.
  #
  FindInList "$@" > /dev/null
} # isInList()

function TestIsInList() {
  
  declare -a List=( 'a' 'b' 'c' 'b' 'd' 'd' '' 'e' )
  declare -a cmd
  local res exp
  
  cmd=( isInList 'a' "${List[@]}" )
  exp=0
  "${cmd[@]}"
  res=$?
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "\`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( isInList 'b' "${List[@]}" )
  exp=0
  "${cmd[@]}"
  res=$?
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "\`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( isInList 'c' "${List[@]}" )
  exp=0
  "${cmd[@]}"
  res=$?
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "\`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( isInList 'd' "${List[@]}" )
  exp=0
  "${cmd[@]}"
  res=$?
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "\`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( isInList 'e' "${List[@]}" )
  exp=0
  "${cmd[@]}"
  res=$?
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "\`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( isInList 'f' "${List[@]}" )
  exp=1
  "${cmd[@]}"
  res=$?
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "\`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( isInList '' "${List[@]}" )
  exp=0
  "${cmd[@]}"
  res=$?
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "\`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  
  #
  # all tests done
  #
  if [[ $nErrors -gt 0 ]]; then
    ERROR "${FUNCNAME}: ${nErrors} tests failed."
  fi
  
  return $nErrors
} # TestIsInList()


function RemoveFromList_indirect() {
  # Removes the specified elements from a list:
  # 
  # ResCmd="$(RemoveFromList_indirect [options] DestList NKeys Keys... [Items...])"
  # eval "$ResCmd"
  # 
  # where `DestList` is the name of the variable where the result should be
  # stored, `NItems` is the number of items in the original list and `Items` are
  # their values. The command `RemoveFromList_indirect` returns a declare-like
  # declaration that, when evaluated, initializes the variable DestList to the
  # new list value
  #
  
  local Option LocalRes=0
  OPTIND=1
  while getopts "lg-" Option ; do
    case "$Option" in
      ( 'l' ) LocalRes=1 ;;
      ( 'g' ) LocalRes=0 ;;
      ( '-' ) break ;;
      ( * )
        CRITICAL "$OPTERR" "${FUNCNAME}: option '${OPTARG}' not supported."
        return
        ;;
    esac
  done
  shift $((OPTIND - 1))
  
  local DestList="$1"
  local -i NKeys="$2"
  shift 2
  local -a Keys
  local -i i
  for (( i = 0 ; i < $NKeys ; ++i )); do
    Keys+=( "$1" )
    shift
  done
  local -a SourceList
  while [[ $# -gt 0 ]]; do
    SourceList+=( "$1" )
    shift
  done
  
  # prepare the local output
  local -a res=( )
  local Item
  for Item in "${SourceList[@]}" ; do
    isInList "$Item" "${Keys[@]}" || res+=( "$Item" )
  done
  
  local resDecl="$(declare -p res)"
  resDecl="${DestList}=${resDecl#*=}"
  if isFlagSet LocalRes ; then
    echo "local -a ${resDecl}"
  else
    echo "declare -a ${resDecl}"
  fi
  
} # RemoveFromList_indirect()


function TestRemoveFromList_indirect() {
  
  declare -a List=( 'a' 'b' 'c' 'b' 'd' 'd' '' 'e' )
  declare -a cmd
  local ResCmd
  local -a ResList
  local res exp ret
  local -i nErrors=0
  
  cmd=( RemoveFromList_indirect -l ResList 1 'a' "${List[@]}" )
  exp=( 'b' 'c' 'b' 'd' 'd' '' 'e' )
  local ResCmd="$( "${cmd[@]}" )"
  eval "$ResCmd"
  if ! isSameList "${#exp[@]}" "${exp[@]}" "${ResList[@]}" ; then
    let ++nErrors
    ERROR "\`${cmd[@]}\` => { $(declare -p ResList) }, cmd='${ResCmd}' ({ $( declare -p exp ) } expected)"
  fi
  
  cmd=( RemoveFromList_indirect -l ResList 1 'b' "${List[@]}" )
  exp=( 'a' 'c' 'd' 'd' '' 'e' )
  local ResCmd="$( "${cmd[@]}" )"
  eval "$ResCmd"
  if ! isSameList "${#exp[@]}" "${exp[@]}" "${ResList[@]}" ; then
    let ++nErrors
    ERROR "\`${cmd[@]}\` => { $(declare -p ResList) }, cmd='${ResCmd}' ({ $( declare -p exp ) } expected)"
  fi
  
  cmd=( RemoveFromList_indirect -l ResList 1 'c' "${List[@]}" )
  exp=( 'a' 'b' 'b' 'd' 'd' '' 'e' )
  local ResCmd="$( "${cmd[@]}" )"
  eval "$ResCmd"
  if ! isSameList "${#exp[@]}" "${exp[@]}" "${ResList[@]}" ; then
    let ++nErrors
    ERROR "\`${cmd[@]}\` => { $(declare -p ResList) }, cmd='${ResCmd}' ({ $( declare -p exp ) } expected)"
  fi
  
  cmd=( RemoveFromList_indirect -l ResList 1 'd' "${List[@]}" )
  exp=( 'a' 'b' 'c' 'b' '' 'e' )
  local ResCmd="$( "${cmd[@]}" )"
  eval "$ResCmd"
  if ! isSameList "${#exp[@]}" "${exp[@]}" "${ResList[@]}" ; then
    let ++nErrors
    ERROR "\`${cmd[@]}\` => { $(declare -p ResList) }, cmd='${ResCmd}' ({ $( declare -p exp ) } expected)"
  fi
  
  cmd=( RemoveFromList_indirect -l ResList 1 'e' "${List[@]}" )
  exp=( 'a' 'b' 'c' 'b' 'd' 'd' '' )
  local ResCmd="$( "${cmd[@]}" )"
  eval "$ResCmd"
  if ! isSameList "${#exp[@]}" "${exp[@]}" "${ResList[@]}" ; then
    let ++nErrors
    ERROR "\`${cmd[@]}\` => { $(declare -p ResList) }, cmd='${ResCmd}' ({ $( declare -p exp ) } expected)"
  fi
  
  cmd=( RemoveFromList_indirect -l ResList 1 'f' "${List[@]}" )
  exp=( 'a' 'b' 'c' 'b' 'd' 'd' '' 'e' )
  local ResCmd="$( "${cmd[@]}" )"
  eval "$ResCmd"
  if ! isSameList "${#exp[@]}" "${exp[@]}" "${ResList[@]}" ; then
    let ++nErrors
    ERROR "\`${cmd[@]}\` => { $(declare -p ResList) }, cmd='${ResCmd}' ({ $( declare -p exp ) } expected)"
  fi
  
  cmd=( RemoveFromList_indirect -l ResList 1 '' "${List[@]}" )
  exp=( 'a' 'b' 'c' 'b' 'd' 'd' 'e' )
  local ResCmd="$( "${cmd[@]}" )"
  eval "$ResCmd"
  if ! isSameList "${#exp[@]}" "${exp[@]}" "${ResList[@]}" ; then
    let ++nErrors
    ERROR "\`${cmd[@]}\` => { $(declare -p ResList) }, cmd='${ResCmd}' ({ $( declare -p exp ) } expected)"
  fi
  
  #
  # all tests done
  #
  if [[ $nErrors -gt 0 ]]; then
    declare -p List
    ERROR "${FUNCNAME}: ${nErrors} tests failed."
  fi
  
  return $nErrors
  
  
} # TestRemoveFromList_indirect()


###
###  messages
###

# functions are always redefined
function STDERR() {
	echo -e "$*" >&2
} # STDERR()

function STDERRwithDebugN() {
  local -i N="$1"
  shift
  local msg
  isDebugging && msg+="${FUNCNAME[N+1]}@${BASH_LINENO[N]}| "
  msg+="$*"
  echo -e "$msg" >&2
} # STDERRwithDebugN()

function STDERRwithDebug() {
  STDERRwithDebugN 1 "$@"
} # STDERRwithDebug()

function INFO() {
	STDERRwithDebugN 1 "${InfoColor}$*${ResetColor}"
} # INFO()

function WARN() {
	STDERRwithDebugN 1 "${WarnColor}Warning: $*${ResetColor}"
} # WARN()

function ERROR() {
	STDERRwithDebugN 1 "${ErrorColor}Error: $*${ResetColor}"
} # ERROR()

function CRITICAL_N() {
	# A version of FATAL for functions expected to be called from command line.
	# It only prints an error message. FATAL-like usage is envisioned as:
	#     
	#     CRITICAL_N 1 2 "File not found!"
	#     return $?
	#     
	# 
	local N="$1"
	local Code="$2"
	shift 2
	STDERRwithDebugN "$((N + 1))" "${FatalColor}Fatal error (${Code}): $*${ResetColor}"
	return $Code
} # CRITICAL()
function CRITICAL() { CRITICAL_N 1 "$@" ; }


function FATAL_N() {
  local N="$1"
  shift
  CRITICAL_N "$((N + 1))" "$@"
  exit $? # CRITICAL_N() returns the exit code
} # FATAL()

function FATAL() { FATAL_N 1 "$@" ; }


function LASTFATAL() {
	local Code="$?"
	[[ "$Code" != 0 ]] && FATAL_N 1 $Code $*
} # LASTFATAL()


###
###  debugging
###
function isDebugging() {
	isFlagSet DEBUG
}

function DBG_N() {
  local N="$1"
  shift
  STDERRwithDebugN "$((N + 1))" "${DebugColor}DBG| $*${ResetColor}"
} # DBG_N()

function DBG() {
	isDebugging && DBG_N 1 "$@"
} # DBG()

function DBGN() {
	# DBGN DebugLevel Debug Message
	# Debug message is printed only if current DEBUG level is bigger or equal to
	# DebugLevel.
	local -i DebugLevel="$1"
	shift
	[[ -n "$DEBUG" ]] && [[ "$DEBUG" -ge "$DebugLevel" ]] && DBG_N 1 "$@"
} # DBGN()

function DUMPVAR() {
	local VarName="$1"
	DBG "'${VarName}'='${!VarName}'"
} # DUMPVAR()

function DUMPVARS() {
	local VarName
	for VarName in "$@" ; do
		DUMPVAR "$VarName"
	done
} # DUMPVARS()

function PrintBashCallStack() {
	#
	# PrintBashCallStack [Levels]
	#
	# Prints a list of the callers of the current function (this one excluded).
	# Prints at most Levels callers, or all of them if not specified or non-positive.
	# It always prints at least one caller (if available).
	#
	local -i Limit=${1:-"0"}
	local -i StackFrameNo=0
	while caller $((++StackFrameNo)) ; do [[ $StackFrameNo == $Limit ]] && break ; done
	return 0
} # PrintBashCallStack()


###
### path utilities
###
function AppendSlash() {
	local DirName="$1"
	if [[ -n "$DirName" ]]; then
		echo "${DirName%%/}/"
	else
		echo
	fi
} # AppendSlash()

function RemoveSlash() {
	local DirName="$1"
	if [[ -z "$DirName" ]]; then
		echo
	elif [[ -z "${DirName%%/}" ]]; then
		echo '/'
	else
		echo "${DirName%%/}"
	fi
} # RemoveSlash()

function IsAbsolutePath() {
  # Returns whether the specified path looks like an absolute path.
  local Path="$1"
  [[ "${Path:0:1}" == '/' ]]
} # IsAbsolutePath()

function MakeAbsolutePath() {
  # Prints an absolute path version of the specified path, using current
  # directory to complete relative paths.
  # It does not support protocol names.
  local Path="$1"
  
  if IsAbsolutePath "$Path" ; then
    echo "$Path"
    return 0
  fi
  
  local Cwd="$(pwd)"
  [[ "$Path" == '.' ]] && Path=''
  echo "${Cwd}${Path:+"/${Path#./}"}"
  
} # MakeAbsolutePath()


###
### path list utilities
###
function InsertPath() {
	#
	# See "DoHelp" section in the code for usage directions.
	#
	DBG "${FUNCNAME} $*"
	
	local Option Separator=':' Prepend=0 AllowDuplicates=1 Move=0 DoHelp=0
	local -a Checks AfterItems BeforeItems
	local OldOPTIND="$OPTIND"
	OPTIND=1
	while getopts ":ed1Dmaps:A:B:h-" Option ; do
		case "$Option" in
			( 'e' | 'd' ) Checks=( "${Checks[@]}" "-${Option}" ) ;;
			( '1' ) AllowDuplicates=0 ;;
			( 'D' ) AllowDuplicates=1 ;;
			( 'm' ) Move=1 ;;
			( 'a' ) Prepend=0 ;;
			( 'p' ) Prepend=1 ;;
			( 's' ) Separator="$OPTARG" ;;
			( 'h' ) DoHelp=1 ;;
			( 'A' ) AfterItems+=( "$OPTARG" ) ;;
			( 'B' ) BeforeItems+=( "$OPTARG" ) ;;
			( '-' ) break ;;
			( '?' ) # this is getopts quietly telling us the option is invalid
				if [[ "$OPTARG" == '?' ]]; then
					DoHelp=1
					continue
				fi
				CRITICAL "$OPTERR" "${FUNCNAME}: option '${OPTARG}' not supported."
				;;
			#	;& # this would be bash 4 syntax
			( * )
				CRITICAL "$OPTERR" "${FUNCNAME}: option '${OPTARG}' not supported."
				return
				;;
		esac
	done
	shift $((OPTIND - 1))
	OPTIND="$OldOPTIND"
	
	local VarName="$1"
	shift
	
	if isFlagSet DoHelp ; then
		cat <<-EOH
			
			${FUNCNAME}  [options] VarName Path [Path ...]
			
			Insert paths to a list of paths separated by a separator in VarName.
			The resulting list is printed out.
			
			Options:
			-s SEP [':']
			    specify the separation string (default: ':')
			-D
			    allow for duplicate items (default)
			-1 (the number "one"!)
			    do not allow for duplicate items (existing and added): if an element
			    is already present, it is not added again
			-m
			    ("move") do not add paths already present; when duplicates are allowed
			    (\`-D\`), if the Path is already present the list is left untouched;
			    if duplicates are not allowed (\`-1\`), if the Path is already present
			    it is moved to the beginning (prepend mode) or end (append mode),
			    and all other instances of Path are removed
			-a
			    append (default)
			-p
			    prepend
			-e
			    add a Path only if it exists
			-d
			    add a Path only if it is an existing directory
			-A afterPath
			    the new paths are added not before than the specified afterPath;
			    only used when prepending (\`-p\`); can be specified multiple times
			-h , -?
			    print this help
			
		EOH
		return 0
	fi
	
	local -a KnownItems WrittenItems
	local -a ItemsToInsert=( "$@" )
	local OldIFS="$IFS"
	IFS="$Separator"
	read -a KnownItems <<< "${!VarName}"
	IFS="$OldIFS"
	local -ir nKnownItems="${#KnownItems[@]}"
	
	if isFlagSet Prepend ; then
		
		[[ "${#BeforeItems[@]}" -ne 0 ]] && CRITICAL "Prepending (\`-p\`) /before/ specific elements (\`-B\`) is not supported." && return 1
		
		local Check
		local -i iKnownWritten=-1
		
		# if the new items need to be set after some known ones, take care of that
		# first:
		if [[ "${#AfterItems[@]}" -gt 0 ]]; then
			
			# find the last among the items in After
			local -i HighestIndex="-1"
			local AfterItem
			local Index
			for AfterItem in "${AfterItems[@]}" ; do
				Index=$(FindLastInList "$AfterItem" "${KnownItems[@]}")
				DBG "Highest index for item '${AfterItem}': ${Index:-none}"
				[[ ${Index:- -1} -gt $HighestIndex ]] && HighestIndex="$Index"
			done
			
			if [[ $HighestIndex -ge 0 ]]; then
				# write all the items before the one found
				local i
				for (( i = 0 ; i <= $HighestIndex ; ++i )); do
					local KnownItem="${KnownItems[i]}"
					
					if isFlagUnset AllowDuplicates ; then
						if isFlagSet Move && isInList "$KnownItem" "$@" ; then
							# the existing item we are going to write now
							# is among the items to be added; since we were asked to move the
							# items to the new position if already present, we skip the item
							continue
						fi
						
						# we do not allow duplicates at all: check we haven't written this yet
						isInList "$KnownItem" "${WrittenItems[@]}" && continue
					fi
					
					[[ "${#WrittenItems[@]}" == 0 ]] || printf '%s' "$Separator"
					printf '%s' "$KnownItem"
					WrittenItems=( "${WrittenItems[@]}" "$KnownItem" )
				done
				
				# we have dealt with all the known items up to the "HighestIndex" one:
				let iKnownWritten+=(HighestIndex + 1)
				DBG "Elements up to #${iKnownWritten} (included) written as prolog."
			fi
		fi
		
		# reparse the elements to insert: if we are not asked to move them and they
		# already exist, they should not be inserted; also, if we are asked to move
		# and duplicates are allowed, the items should not be written as well.
		if ( isFlagUnset Move && isFlagUnset AllowDuplicates ) || ( isFlagSet Move && isFlagSet AllowDuplicates ) ; then
			local Item
			for Item in "${ItemsToInsert[@]}" ; do
				if isInList "$Item" "${KnownItems[@]}" ; then
					local rmCmd="$(RemoveFromList_indirect ItemsToInsert 1 "$Item" "${ItemsToInsert[@]}")"
					eval "$rmCmd"
				fi
			done
		fi
		
		# first write the new items
		for Item in "${ItemsToInsert[@]}" ; do
			for Check in "${Checks[@]}" ; do
				test "$Check" "$Item" || continue 2
			done
			
			if isFlagUnset AllowDuplicates ; then
				isInList "$Item" "${WrittenItems[@]}" && continue
			fi
			
			[[ "${#WrittenItems[@]}" == 0 ]] || printf '%s' "$Separator"
			printf '%s' "$Item"
			WrittenItems=( "${WrittenItems[@]}" "$Item" )
		done # items
		local -i nAddedItems=${#WrittenItems[@]}
		
		# now write the items which were there already and which have not been
		# written already
		while [[ $((++iKnownWritten)) -lt "$nKnownItems" ]]; do
			KnownItem="${KnownItems[iKnownWritten]}"
			
			local -i nDupCheck=0
			isFlagSet Move && nDupCheck=$nAddedItems
			isFlagUnset AllowDuplicates && nDupCheck=${#WrittenItems[@]}
			
			local iWrittenItem
			for (( iWrittenItem = 0; iWrittenItem < $nDupCheck ; ++iWrittenItem )); do
				[[ "${WrittenItems[iWrittenItem]}" == "$KnownItem" ]] && continue 2
			done
			
			[[ "${#WrittenItems[@]}" == 0 ]] || printf '%s' "$Separator"
			printf '%s' "$KnownItem"
			WrittenItems=( "${WrittenItems[@]}" "$KnownItem" )
		done
	else # append
		
		[[ "${#AfterItems[@]}" -ne 0 ]] && CRITICAL "Appending (\`-a\`) /after/ specific elements (\`-A\`) is not supported." && return 1
		
		# if the new items need to be set after some known ones, take care of that
		# first:
    local -i LowestIndex="$nKnownItems"
		if [[ "${#BeforeItems[@]}" -gt 0 ]]; then
			# find the last among the items in After
			local BeforeItem
			local Index
			for BeforeItem in "${BeforeItems[@]}" ; do
				Index=$(FindInList "$BeforeItem" "${KnownItems[@]}")
				DBG "Lowest index for item '${BeforeItem}': ${Index:-none}"
				[[ ${Index:-$nKnownItems} -lt $LowestIndex ]] && LowestIndex="$Index"
			done
			DBG "Selected insertion point before index #${LowestIndex}"
		fi
		
		# first write the items which are there already
		local -i iKnown=0
		while [[ $iKnown -lt $LowestIndex ]]; do
			KnownItem="${KnownItems[iKnown++]}"
			
			if isFlagUnset AllowDuplicates ; then
				
				# if we are asked to move the items and this item is requested to be
				# appended, it is erased from this position if no duplicates are
				# allowed, otherwise it is preserved
				if isFlagSet Move && isFlagUnset AllowDuplicates; then
					isInList "$KnownItem" "${ItemsToInsert[@]}" && continue
				fi
				
				# in general, duplicates are not allowed
				isInList "$KnownItem" "${WrittenItems[@]}" && continue
			fi
			
			[[ "${#WrittenItems[@]}" == 0 ]] || printf '%s' "$Separator"
			printf '%s' "$KnownItem"
			WrittenItems+=( "$KnownItem" )
		done
		
		# then the new ones
		local Item
		for Item in "${ItemsToInsert[@]}" ; do
			for Check in "${Checks[@]}" ; do
				test "$Check" "$Item" || continue 2
			done
			
			if isFlagUnset AllowDuplicates ; then
				isInList "$Item" "${WrittenItems[@]}" && continue
			else
				# if we are moving and accepting duplication, and the item is already
				# somewhere there at the beginning,
				# the whole thing is a no-op for this insertion item
				DBG "Checking whether '${Item}' is in ${KnownItems[@]}"
				isFlagSet Move && isInList "$Item" "${KnownItems[@]}" && continue
			fi
		#	( isFlagUnset AllowDuplicates || isFlagSet Move ) && isInList "$Item" "${WrittenItems[@]}" && continue
			
			[[ "${#WrittenItems[@]}" == 0 ]] || printf '%s' "$Separator"
			printf '%s' "$Item"
			WrittenItems=( "${WrittenItems[@]}" "$Item" )
		done
		
		# if there are still items to be written, do it now
		while [[ $iKnown -lt $nKnownItems ]]; do
			# write all the items after the insertion point
			local KnownItem="${KnownItems[iKnown++]}"
			
			# do not write duplicates if so requested
			isFlagUnset AllowDuplicates && isInList "$KnownItem" "${WrittenItems[@]}" && continue
			
			[[ "${#WrittenItems[@]}" == 0 ]] || printf '%s' "$Separator"
			printf '%s' "$KnownItem"
			WrittenItems=( "${WrittenItems[@]}" "$KnownItem" )
		done
		
	fi # prepend/append
	
	printf "\n"
	return 0
} # InsertPath()


function TestInsertPath() {
  
  local res exp
  local -a cmd
  local -i nErrors=0
  local -r TestPath="1:2:3:2:4:4:5:6"
  
  ###
  ### default duplication option (currently: allow duplicates)
  ###
  #
  # insertions of a new element
  #
  cmd=( InsertPath TestPath '7' )
  exp="1:2:3:2:4:4:5:6:7"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -a TestPath '7' )
  exp="1:2:3:2:4:4:5:6:7"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p TestPath '7' )
  exp="7:1:2:3:2:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of a duplicate element
  #
  cmd=( InsertPath -a TestPath '2' )
  exp="1:2:3:2:4:4:5:6:2"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p TestPath '2' )
  exp="2:1:2:3:2:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of a duplicate element (same as first one)
  #
  cmd=( InsertPath -a TestPath '1' )
  exp="1:2:3:2:4:4:5:6:1"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p TestPath '1' )
  exp="1:1:2:3:2:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of a duplicate element (same as last one)
  #
  cmd=( InsertPath -a TestPath '6' )
  exp="1:2:3:2:4:4:5:6:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p TestPath '6' )
  exp="6:1:2:3:2:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  ###
  ### allow duplicates ('-D')
  ###
  #
  # insertions of a new element
  #
  cmd=( InsertPath -a -D TestPath '7' )
  exp="1:2:3:2:4:4:5:6:7"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p -D TestPath '7' )
  exp="7:1:2:3:2:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of a duplicate element
  #
  cmd=( InsertPath -a -D TestPath '2' )
  exp="1:2:3:2:4:4:5:6:2"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p -D TestPath '2' )
  exp="2:1:2:3:2:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of a duplicate element (same as first one)
  #
  cmd=( InsertPath -a -D TestPath '1' )
  exp="1:2:3:2:4:4:5:6:1"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p -D TestPath '1' )
  exp="1:1:2:3:2:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of a duplicate element (same as last one)
  #
  cmd=( InsertPath -a -D TestPath '6' )
  exp="1:2:3:2:4:4:5:6:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p -D TestPath '6' )
  exp="6:1:2:3:2:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  ###
  ### do not allow duplicates ('-1')
  ###
  #
  # insertions of a new element
  #
  cmd=( InsertPath -a -1 TestPath '7' )
  exp="1:2:3:4:5:6:7"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p -1 TestPath '7' )
  exp="7:1:2:3:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of a duplicate element
  #
  cmd=( InsertPath -a -1 TestPath '2' )
  exp="1:2:3:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p -1 TestPath '2' )
  exp="1:2:3:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of a duplicate element (same as first one)
  #
  cmd=( InsertPath -a -1 TestPath '1' )
  exp="1:2:3:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p -1 TestPath '1' )
  exp="1:2:3:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of a duplicate element (same as last one)
  #
  cmd=( InsertPath -a -1 TestPath '6' )
  exp="1:2:3:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p -1 TestPath '6' )
  exp="1:2:3:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  ###
  ### move (allows duplicates, only acts if inserted key is not present) ('-m -D')
  ###
  #
  # insertions of a new element
  #
  cmd=( InsertPath -a -m -D TestPath '7' )
  exp="1:2:3:2:4:4:5:6:7"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p -m -D TestPath '7' )
  exp="7:1:2:3:2:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of a duplicate element
  #
  cmd=( InsertPath -a -m -D TestPath '2' )
  exp="1:2:3:2:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p -m -D TestPath '2' )
  exp="1:2:3:2:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of a duplicate element (same as first one)
  #
  cmd=( InsertPath -a -m -D TestPath '1' )
  exp="1:2:3:2:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p -m -D TestPath '1' )
  exp="1:2:3:2:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of a duplicate element (same as last one)
  #
  cmd=( InsertPath -a -m -D TestPath '6' )
  exp="1:2:3:2:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p -m -D TestPath '6' )
  exp="1:2:3:2:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  
  ###
  ### move (does not allow any duplicate) ('-m -1')
  ###
  #
  # insertions of a new element
  #
  cmd=( InsertPath -a -m -1 TestPath '7' )
  exp="1:2:3:4:5:6:7"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p -m -1 TestPath '7' )
  exp="7:1:2:3:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of a duplicate element
  #
  cmd=( InsertPath -a -m -1 TestPath '2' )
  exp="1:3:4:5:6:2"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p -m -1 TestPath '2' )
  exp="2:1:3:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of a duplicate element (same as first one)
  #
  cmd=( InsertPath -a -m -1 TestPath '1' )
  exp="2:3:4:5:6:1"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p -m -1 TestPath '1' )
  exp="1:2:3:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of a duplicate element (same as last one)
  #
  cmd=( InsertPath -a -m -1 TestPath '6' )
  exp="1:2:3:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p -m -1 TestPath '6' )
  exp="6:1:2:3:4:5"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  
  ###
  ### prepending after some values (`-A`)
  ###
  #
  # insertions of a new element after two existing and a non-existing element
  #
  cmd=( InsertPath -p -A 1 -A 4 -A 8 TestPath '7' )
  exp="1:2:3:2:4:4:7:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of an existing element after two existing and a non-existing element
  #
  cmd=( InsertPath -p -A 1 -A 4 -A 8 TestPath '2' )
  exp="1:2:3:2:4:4:2:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p -A 1 -A 4 -A 8 TestPath '6' )
  exp="1:2:3:2:4:4:6:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  ###
  ### prepending after some values (`-A`) when allowing duplicates (`-D`)
  ###
  #
  # insertions of a new element after two existing and a non-existing element
  #
  cmd=( InsertPath -p -A 1 -A 4 -A 8 -D TestPath '7' )
  exp="1:2:3:2:4:4:7:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of an existing element after two existing and a non-existing element
  #
  cmd=( InsertPath -p -A 1 -A 4 -A 8 -D TestPath '2' )
  exp="1:2:3:2:4:4:2:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p -A 1 -A 4 -A 8 -D TestPath '6' )
  exp="1:2:3:2:4:4:6:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  ###
  ### prepending after some values (`-A`) when not allowing duplicates (`-1`)
  ###
  #
  # insertions of a new element after two existing and a non-existing element
  #
#  local -r TestPath="1:2:3:2:4:4:5:6"
  
  cmd=( InsertPath -p -A 1 -A 4 -A 8 -1 TestPath '7' )
  exp="1:2:3:4:7:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of an existing element after two existing and a non-existing element
  #
  cmd=( InsertPath -p -A 1 -A 4 -A 8 -1 TestPath '2' )
  exp="1:2:3:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p -A 1 -A 4 -A 8 -1 TestPath '6' )
  exp="1:2:3:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  ###
  ### prepending after some values (`-A`) when moving (`-m`) and allowing duplicates (`-D`)
  ###
  #
  # insertions of a new element after two existing and a non-existing element
  #
  cmd=( InsertPath -p -A 1 -A 4 -A 8 -m -D TestPath '7' )
  exp="1:2:3:2:4:4:7:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of an existing element after two existing and a non-existing element
  #
  cmd=( InsertPath -p -A 1 -A 4 -A 8 -m -D TestPath '2' )
  exp="1:2:3:2:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p -A 1 -A 4 -A 8 -m -D TestPath '6' )
  exp="1:2:3:2:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  ###
  ### prepending after some values (`-A`) when moving (`-m`) and not allowing duplicates (`-1`)
  ###
  #
  # insertions of a new element after two existing and a non-existing element
  #
  cmd=( InsertPath -p -A 1 -A 4 -A 8 -m -1 TestPath '7' )
  exp="1:2:3:4:7:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of an existing element after two existing and a non-existing element
  #
  cmd=( InsertPath -p -A 1 -A 4 -A 8 -m -1 TestPath '2' )
  exp="1:3:4:2:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -p -A 1 -A 4 -A 8 -m -1 TestPath '6' )
  exp="1:2:3:4:6:5"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  
  ###
  ### appending before some values (`-B`) when allowing duplicates (`-D`)
  ###
  #
  # insertions of a new element before two existing and a non-existing element
  #
  cmd=( InsertPath -a -B 6 -B 4 -B 8 -D TestPath '7' )
  exp="1:2:3:2:7:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of an existing element after two existing and a non-existing element
  #
  cmd=( InsertPath -a -B 6 -B 4 -B 8 -D TestPath '2' )
  exp="1:2:3:2:2:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -a -B 6 -B 4 -B 8 -D TestPath '5' )
  exp="1:2:3:2:5:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  ###
  ### appending before some values (`-B`) when not allowing duplicates (`-1`)
  ###
  #
  # insertions of a new element before two existing and a non-existing element
  #
  cmd=( InsertPath -a -B 6 -B 4 -B 8 -1 TestPath '7' )
  exp="1:2:3:7:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of an existing element after two existing and a non-existing element
  #
  cmd=( InsertPath -a -B 6 -B 4 -B 8 -1 TestPath '2' )
  exp="1:2:3:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -a -B 6 -B 4 -B 8 -1 TestPath '5' )
  exp="1:2:3:5:4:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  ###
  ### appending before some values (`-B`) when moving (`-m`) and allowing duplicates (`-D`)
  ###
  #
  # insertions of a new element before two existing and a non-existing element
  #
  cmd=( InsertPath -a -B 6 -B 4 -B 8 -D -m TestPath '7' )
  exp="1:2:3:2:7:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of an existing element after two existing and a non-existing element
  #
  cmd=( InsertPath -a -B 6 -B 4 -B 8 -D -m TestPath '2' )
  exp="1:2:3:2:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -a -B 6 -B 4 -B 8 -D -m TestPath '5' )
  exp="1:2:3:2:4:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  ###
  ### appending before some values (`-B`) when moving (`-m`) and not allowing duplicates (`-1`)
  ###
  #
  # insertions of a new element before two existing and a non-existing element
  #
  cmd=( InsertPath -a -B 6 -B 4 -B 8 -1 -m TestPath '7' )
  exp="1:2:3:7:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  #
  # insertions of an existing element after two existing and a non-existing element
  #
  cmd=( InsertPath -a -B 6 -B 4 -B 8 -1 -m TestPath '2' )
  exp="1:3:2:4:5:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  cmd=( InsertPath -a -B 6 -B 4 -B 8 -1 -m TestPath '5' )
  exp="1:2:3:5:4:6"
  res="$( "${cmd[@]}" )"
  [[ "$res" != "$exp" ]] && let ++nErrors && ERROR "${FUNCNAME}@${LINENO} - \`${cmd[@]}\` => '${res}' ('${exp}' expected)"
  
  
  #
  # all tests done
  #
  if [[ $nErrors -gt 0 ]]; then
    echo "$(declare -p TestPath)"
    ERROR "${FUNCNAME}: ${nErrors} tests failed."
  fi
  
  return $nErrors
} # TestInsertPath()


function AddToPath() {
	#
	# AddToPath [options] VarName Path [Path ...]
	#
	# Adds paths to a colon-separated list of paths stored in VarName, which is
	# updated with the new value.
	# Options: as for InsertPath
	#
	local Option
	OPTIND=1
	# same option parsing as for `InsertPath()`, just to find the first positional
	# argument:
	while getopts ":ed1Dmaps:A:B:h-" Option ; do
		[[ "$Option" == "-" ]] && break
	done
	
	local VarName="${!OPTIND}"
	# this is sad euristic to figure out if what we get from InsertPath is just help message:
	local InsertPathStatements
        InsertPathStatements="$(InsertPath "$@" )"
	local res=$?
	[[ $res != 0 ]] && return $res
	[[ -n "$InsertPathStatements" ]] || return 0
        local Command
	read Command <<< "$InsertPathStatements"
        if [[ -z "$Command" ]]; then
		echo "$InsertPathStatements"
	else
		eval "export ${VarName}=\"${InsertPathStatements}\""
	fi
} # AddToPath()


function DeletePath() {
	#
	# DeletePath [options] VarName Path [Path ...]
	#
	# Removes paths from a list of paths separated by Separator in VarName.
	# The purged list is printed out.
	#
	# Options:
	# -s SEP     specify the separation string (default: ':')
	#
	local Option Separator=':'
	OPTIND=1
	while getopts "s:-" Option ; do
		case "$Option" in
			( 's' ) Separator="$OPTARG" ;;
			( '-' ) break ;;
		esac
	done
	shift $((OPTIND - 1))
	
	local VarName="$1"
	shift
	
	tr "$Separator" "\n" <<< "${!VarName}" | while read ExistingItem ; do
		
	#	# this code commented out would remove duplicate entries
	#	for KnownItem in "${KnownItems[@]}" ; do
	#		[[ "$Item" == "$KnownItem" ]] && continue 2 # go to the next item
	#	done
		
		# check if we have met this item before
		for Item in "$@" ; do
			[[ "$ExistingItem" == "$Item" ]] && continue 2 # gotcha! skip this
		done
		
		# use a separator if this is not the very first item we have
		[[ "${#KnownItems[@]}" == 0 ]] || printf '%s' "$Separator"
		
		printf '%s' "$ExistingItem"
		
		KnownItems=( "${KnownItems[@]}" "$ExistingItem" )
	done # ( while )
	printf "\n"
	return 0
} # DeletePath()


function PurgeFromPath() {
	#
	# PurgeFromPath [options] VarName Path [Path ...]
	#
	# Removes paths from a list of paths separated by Separator in VarName,
	# which is updated with the new value.
	# Options: the same as DeletePath()
	#
	local Option
	OPTIND=1
	while getopts "s:-" Option ; do
		[[ "$Option" == "-" ]] && break
	done
	
	local VarName="${!OPTIND}"
	eval "export ${VarName}=\"$(DeletePath "$@" )\""
} # PurgeFromPath()


function RemoveDuplicatesFromPath() {
	#
	# RemoveDuplicatesFromPathSep VarName [Separator]
	#
	# Removes duplicate paths from a list of paths separated by Separator in
	# VarName. The purged list is printed out.
	#
	local VarName="$1"
	local Separator="${2:-":"}"
	
	tr "$Separator" "\n" <<< "${!VarName}" | while read Item ; do
		
		for KnownItem in "${KnownItems[@]}" ; do
			[[ "$Item" == "$KnownItem" ]] && continue 2 # go to the next item
		done
		
		# use a separator if this is not the very first item we have
		[[ "${#KnownItems[@]}" == 0 ]] || printf '%s' "$Separator"
		
		printf '%s' "$Item"
		
		KnownItems=( "${KnownItems[@]}" "$Item" )
	done # ( while )
	printf "\n"
	return 0
} # RemoveDuplicatesFromPath()

function PurgeDuplicatesFromPath() {
	#
	# PurgeDuplicatesFromPath VarName [Separator]
	#
	# Removes duplicate paths from a list of paths separated by colons in
	# VarName, which is updated with the new value.
	#
	local VarName="$1"
	eval "export ${VarName}=\"$(RemoveDuplicatesFromPath "$@" )\""
} # PurgeDuplicatesFromPath()


function SetColors() {
	# call this after you know if you want colors or not
	local UseColors="${1:-1}"
	if isFlagSet UseColors ; then
		DBGN 10 "Setting output colors..."
		ErrorColor="$ANSIRED"
		FatalColor="$ANSIRED"
		WarnColor="$ANSIYELLOW"
		DebugColor="$ANSIGREEN"
		InfoColor="$ANSICYAN"
		ResetColor="$ANSIRESET"
	else
		DBGN 10 "Unsetting output colors..."
		ErrorColor=
		FatalColor=
		WarnColor=
		DebugColor=
		InfoColor=
		ResetColor=
	fi
} # SetColors()

###
### Bash-related
###

function betterSource() {
	# 
	# Usage:  betterSource ScriptName [arguments]
	#
	# Sources the specified script with the specified command line arguments.
	# Compared to the built-in `source` command, this one does not add the current argument values
	# when it's called without arguments (i.e. a call without `arguments` always results
	# into sourcing `ScriptName` with no command line arguments).
	#
	# Implementation note: an implementation like `builtin source "$@"` would incur
	# in the same problem as the built-in source. In this case, `betterSource ScriptName`
	# would result in `source "$ScriptName" "$ScriptName"`, since `source` would implicitly
	# append all the arguments of this function (that is, just the script name) to the command.
	#
	local ScriptName="$1"
	shift
	builtin source "$ScriptName" "$@"
} # betterSource()



###
###  unsorted
###
function ReadParam() {
	# ReadParam Options nFirstParameter Parameters
	# reads a parameter PARAM in the form -oPARAM or -o PARAM or --output=PARAM
	# or --output PARAM, prints the PARAM value and returns how many parameters
	# where used (1 in the first and third form, 2 in second and fourth ones,
	# 0 if no option matched).
	# The short/long form are space-separated in Options parameter; the value is
	# extracted from the parameter whose number is stored in nFirstParameter
	# variable (which includes the option) or the next one.
	# If an option ends with a '*', it will be allowed to have a second value not
	# starting with '-'. Otherwise, if the next parameter starts with a '-', the
	# value for this option will be set just to "1" and the next option will be
	# left untouched.
	# If an option ends with a '!', it is required to have a value; it can be the
	# value net to the option, if not starting with '-'. If there is no such a
	# value (e.g. because the option is the last one), an error is reported.
	local Options="$1"
	local nParam="$2"
	shift 2
	
	# get the option itself
	local Option="${!nParam}"
	
	DBGN 10 "ReadParam() testing '${Option}'..."
	for OptionKey in $Options ; do
		AllowDashedValue=0
		MandatoryValue=0
		while [[ -n "$OptionKey" ]]; do
			case "${OptionKey: -1:1}" in
				( "*" )
					AllowDashedValue=0
					;;
				( "!" )
					MandatoryValue=1
					;;
				( * )
					break
					;;
			esac
			DBG "modifier '${OptionKey:${#OptionKey}-1:1}' found in option '${OptionKey:0:${#OptionKey}-1}'"
			OptionKey="${OptionKey:0:${#OptionKey}-1}"
		done
		
		if [[ "$Option" == "$OptionKey" ]]; then
			let ++nParam
			local Value="${!nParam}"
			if isFlagSet AllowDashedValue || [[ "${Value:0:1}" != "-" ]] && [[ $nParam -le $# ]]; then
				DBGN 10 "       ... matched '${OptionKey}' with a separate option"
				echo "$Value"
				return 2
			else
				if isFlagSet MandatoryValue ; then
					ERROR "Option '${OptionKey}' requires value!"
					return 0
				fi
				DBGN 10 "       ... matched '${OptionKey}' with no value"
				echo "1"
				return 1
			fi
		fi
		if [[ "${#OptionKey}" -le 2 ]]; then
			DBGN 10 "   ... against short option '${OptionKey}'"
			if [[ "${Option#${OptionKey}}" != "$Option" ]]; then
				DBG "       ... matched with a integrated option"
				echo "${Option#${OptionKey}}"
				return 1
			fi
		else
			DBGN 10 "   ... against long option '${OptionKey}'"
			if [[ "${Option#${OptionKey}=}" != "$Option" ]]; then
				DBGN 10 "       ... matched with a integrated option"
				echo "${Option#${OptionKey}=}"
				return 1
			fi
		fi
	done
	DBGN 10 "   ... didn't match anything!"
	return 0
} # ReadParam()


function ExpandExecutable() {
	# ExpandExecutable ExecName [AdditionalPath] [AdditionalPath] [...]
	# prints the full name of the specified executable
	# returns whether it was found (0) or not (1)
	local ExecName="$1"
	shift
	
	# first look for it in suggested paths
	local Path
	for Path in "$@" ; do
		Path="$(AppendSlash "$Path")"
		[[ -x "${Path}${ExecName}" ]] && echo "${Path}${ExecName}" && return 0
		
	done
	# last word is to which:
	which "$ExecName" 2> /dev/null
} # ExpandExecutable()


function ExpandFunctionOrExecutable() {
	# ExpandFunctionOrExecutable ExecName [AdditionalPath] [AdditionalPath] [...]
	# prints the full name of the specified function or executable
	# Functions are checked first
	# returns whether it was found (0) or not (1)
	local ExecName="$1"
	if declare -F "$ExecName" >& /dev/null ; then
		echo "$Executable"
		return 0
	fi
	# otherwise just call ExpandExecutable()
	ExpandExecutable "$@"
} # ExpandFunctionOrExecutable()


function CompressionFormat() {
	# CompressionFormat FileName
	# returns the file suffix of a know compression format
	local -a KnownFormats=( '.tar.gz' '.tar.bz2' '.tar.7z' '.gz' '.bz2' '.7z' )
	local File="$1"
	for Format in "${KnownFormats[@]}" ; do
		if [[ "${File%${Format}}" != "$File" ]]; then
			echo "$Format"
			return 0
		fi
	done
	echo
	return 1
} # CompressionFormat()


function Compress() {
	# Compress Format [SourceFile]
	# If SourceFile is specified, its data is compressed; if not, the data is
	# read from stdin. In both cases, compressed data is output to stdout.
	local Format="$1"
	local FileName="$2"
	local CompressCmd="cat"
	case "$Format" in
		( '.gz' )
			CompressCmd="gzip -c"
			;;
		( '.bz2' )
			CompressCmd="bzip2 -c"
			;;
		( '' )
		( * )
			CompressCmd="cat"
			;;
	esac
	if [[ -n "$FileName" ]]; then
		$CompressCmd "$FileName"
	else
		$CompressCmd
	fi
} # Compress()


function Uncompress() {
	# Uncompress [FileName [Format]]
	# writes to standard output uncompressed data from one input file or from
	# standard input (in which case you have to specify the format or data will
	# not be uncompressed at all).
	local FileName="$1"
	local Format="$2"
	[[ $# -le 1 ]] && Format="$(CompressionFormat "$FileName")"
	local UncompressCmd="cat"
	case "$Format" in
		( '.gz' | '.tar.gz' | '.tgz' )
			UncompressCmd="zcat"
			;;
		( '.bz2' | '.tar.bz2' | '.tbz2' )
			UncompressCmd="bzcat"
			;;
		( * )
			UncompressCmd="cat"
			;;
	esac
	DBGN 2 "Using '${UncompressCmd}' to uncompress '${FileName:-"<stdin>"}' (format: '${Format}')"
	if [[ -n "$FileName" ]]; then
		$UncompressCmd "$FileName"
	else
		$UncompressCmd
	fi
} # Uncompress()


function DetectNCPUs() {
  #
  # Usage:  DetectNCPUs
  #
  # Prints on screen the maximum number of hardware threads available.
  #
  if [[ -r '/proc/cpuinfo' ]]; then
    grep -c 'processor' '/proc/cpuinfo'
    return 0
  else
    sysctl -n 'hw.ncpu' 2> /dev/null
    return
  fi
  return 1
} # DetectNCPUs()


function isNonNegativeInteger() {
	local Number="$1"
	[[ -z "${Number//[0-9]}" ]]
} # isNonNegativeInteger()

function isInteger() {
	local Number="$1"
	Number="${Number#-}" # may have a sign
	isNonNegativeInteger "$Number"
} # isInteger()

function isNonNegativeRealNumber() {
	local Number="$1"
	Number="${Number/.}" # we can accept one decimal point
	isInteger "$Number"
} # isNonNegativeRealNumber()

function isRealNumber() {
	local Number="$1"
	Number="${Number#-}" # may have a sign
	isNonNegativeRealNumber "$Number"
} # isRealNumber()

function isPositiveInteger() {
	local Number="$1"
	isNonNegativeInteger "$Number" && [[ "$Number" -gt 0 ]]
} # isPositiveInteger()

###############################################################################
### Meta: function managing
###

function ReloadFunctions() {
	
	local FunctionPath="${1:-"$FUNCTIONS_SH_LOADED"}"
	if [[ ! -r "$FunctionPath" ]]; then
		 CRITICAL 1 "Functions script is not at '${FunctionPath}' any more!!"
		 return $?
	fi
	
	INFO "Reloading functions from '${FunctionPath}'"
	unset FUNCTIONS_SH_LOADED
	source "$FunctionPath"
	local res=$?
	if [[ $res != 0 ]]; then
		CRITICAL $res "Failed resourcing functions from '${FunctionPath}'!"
		return $?
	fi
	
} # ReloadFunctions()


###############################################################################
### alias-like functions
###
function md() {
	local Param
	local Dir=
	local -i Parent=0 NoMoreOptions=0
	for Param in "$@" ; do
		if [[ "${Param:0:1}" == '-' ]] && isFlagUnset NoMoreOptions ; then
			case "$Param" in
				( '-h' | '--help' | '-?' )
					cat <<-EOH
					Creates the specified directory (if needed) and prints it.
					
					Usage:  md [options] DirName
					
					Options
					--parent , -p , -p#
					    creates only the parent directory of DirName, or the #-th parent only;
					    the options can be repeated; -pp is equivalent to -p2, -ppp to -p3
					    and so on. The directory written on screen is still DirName.
					
					EOH
					return 0
					;;
				( '-p' | '--parent' )
					let ++Parent
					;;
				( '-p'* )
					if [[ "${Param//p}" == '-' ]]; then
						Parent=$((${#Param} - 1))
					else
						let Parent+="${Param#-p}" >& /dev/null
						if [[ $? != 0 ]]; then
							ERROR "Invalid option -- '${Param}'"
							return 1
						fi
					fi
					;;
				( '-' | '--' )
					NoMoreOptions=1
					;;
				( -* )
					ERROR "Invalid option -- '${Param}'"
					return 1
			esac
		else
			if [[ -n "$Dir" ]]; then
				ERROR "too many directories specified: '${Dir}', and then '${Param}'."
				return 1
			fi
			Dir="$Param"
			NoMoreParams=1
		fi
	done
	local CreateDir="$Dir"
	while [[ $Parent -gt 0 ]]; do
		CreateDir="$(dirname "$CreateDir")"
		let --Parent
	done
	mkdir -p "$CreateDir"
	echo "$Dir"
	[[ -d "$CreateDir" ]]
} # md()
unalias md >& /dev/null


function chdir() {
	local Dir="$1"
	mkdir -p "$1"
	cd "$1"
} # chdir()
export -f chdir


function canonical_path() {
	#
	# Usage:  canonical_path Path
	#
	# Prints a canonical version of the specified path.
	# It does not turn the path from relative to absolute (see full_path)
	#
	local Option
	local -i FollowLinks=0 AbsolutePath=0 DoHelp=0
	OPTIND=1
	while getopts "afh?-" Option ; do
		case "$Option" in
			( 'f' ) FollowLinks=1 ;;
			( 'a' ) AbsolutePath=1 ;;
			( 'h' ) DoHelp=1 ;;
			( '?' | '-' ) break ;;
		esac
	done
	shift $((OPTIND - 1))
	
	if [[ "$DoHelp" != 0 ]]; then
		cat <<-EOH
		Prints a canonical version of the specified path.
		
		Usage: canonical_path [options] [--] Path
		
		Relative paths are not turned into absolute (see full_path for that).
		
		Options:
		    -f
		        follow symbolic links; the final path will contain no symbolic link
		    -a
		        force an absolute path, completing relative paths with the current directory
		
		EOH
		return 0
	fi
	
	local Path="$1"
	
	# make path absolute if requested
	[[ "$AbsolutePath" != 0 ]] && [[ "${Path:0:1}" != '/' ]] && Path="$(pwd)${Path:+/${Path}}"
	
	# if the path is not just '/', remove any trailing '/'
	while [[ "${Path: -1}" == '/' ]]; do
		# short cut: if the path is root, we are done already
		[[ "$Path" == '/' ]] && echo "/" && return 0
		Path="${Path:0:${#Path}-1}"
	done
	
	local -i Parents=0 # parent directories that we are not given to see
	local -a Dirs
	local -i NDirs=0
	local Name
	
	local MergedPath=""
	
	# analyse piece by piece
	while [[ -n "$Path" ]] ; do
		
		# pick the first part of the path (up to the first '/' left);
		# absolute paths, that start with '/', get this first name an empty one
		Name="${Path%%/*}"
		
		# remove this part from the path (and also trailing '/')
		Path="${Path#${Name}}"
		while [[ "${Path:0:1}" == '/' ]] ; do
			Path="${Path#/}"
		done
		case "$Name" in
			( '.' ) ;;
			( '..' )
				if [[ $NDirs -gt 0 ]]; then
					let --NDirs
					MergedPath="${MergedPath%/*/}/"
				else
					let ++Parents
				fi
				;;
			( * )
				Dirs[NDirs++]="$Name"
				MergedPath+="${Name}/"
				;;
		esac
		if [[ "$FollowLinks" != 0 ]] && [[ -n "$MergedPath" ]] && [[ "$MergedPath" != "/" ]] && [[ -h "${MergedPath%/}" ]] ; then
			# restart from scratch...
			local NewPath
			NewPath="$(readlink "${MergedPath%/}")"
			if [[ "${NewPath:0:1}" != "/" ]]; then
				local LinkDirName="$(dirname "$MergedPath")"
				[[ -n "$LinkDirName" ]] && NewPath="${LinkDirName%/}/${NewPath}"
			fi
			[[ -n "$Path" ]] && NewPath+="/${Path}"
			canonical_path -f -- "$NewPath"
			return
		fi 
	done
	
	local FullPath
	while [[ $((Parents--)) -gt 0 ]]; do
		FullPath+="../"
	done
	for Name in "${Dirs[@]}" ; do
		FullPath+="${Name}/"
	done
	echo "${FullPath%/}"
	
	return 0
} # canonical_path()
export -f canonical_path


function full_path() {
	#
	# Usage:  full_path Path
	#
	# Prints a canonical version of the specified path.
	# If relative, it's assumed to start from the current directory.
	local Option
	local -i DoHelp=0
	local -a PassArguments
	OPTIND=1
	while getopts "fh?-" Option ; do
		case "$Option" in
			( 'h' | '?' ) DoHelp=1 ;;
			( 'f' ) PassArguments=( "${PassArguments[@]}" "-${Option}" ) ;;
			( '-' ) break ;;
		esac
	done
	
	local Path="${!OPTIND}"
	
	if [[ "$DoHelp" != 0 ]] || [[ -z "$Path" ]] ; then
		cat <<-EOH
		Prints a canonical version of the specified path.
		
		Usage: full_path [options] [--] Path
		
		Relative paths are turned into absolute.
		
		Options:
		    -f
		        follow symbolic links; the final path will contain no symbolic link 
		
		EOH
		[[ "$DoHelp" != 0 ]] # sets the return value
		return 0
	fi
	
	canonical_path "${PassArguments[@]}" -a -- "$Path"
	
} # full_path()
export -f full_path


function datetag() {
	# parameters
	
	local FORMAT=
	local SECONDFRACTION=0
	
	for Param in "$@" ; do
		[[ -n "$FORMAT" ]] && break
		case "$Param" in
			( -s | --seconds )
				FORMAT="%Y%m%d%H%M%S"
				;;
			( -m | --minutes )
				FORMAT="%Y%m%d%H%M"
				;;
			( -c | --cents )
				FORMAT="%Y%m%d%H%M%S"
				SECONDFRACTION=2
				;;
			( -h | --help | -? )
				cat <<-EOH
				Prints a timestamp tag.
				
				Usage:  ${SCRIPTNAME} [options]
				
				By default, a format 'YYYYMMDD' is used.
				Here, the YYYY is a four digits year, MM a two digits month, DD a two digits
				day. Additional HHMM means hours and minutes, two digits each, additional SS is
				two digits seconds and CC is two digits hundreths of second. 
				
				
				Supported options:
				
				-c , --cents
					format: YYYYMMDDHHMMSSCC
				-s , --seconds
					format: YYYYMMDDHHMMSS
				-m , --minutes
					format: YYYYMMDDHHMM
				
				EOH
				return 0
			( * )
				ERROR "Format option '${Param}' not supported."
				return 1
		esac
	done
	
	[[ -z "$FORMAT" ]] && FORMAT="%Y%m%d"
	
	local MAINDATE="$(date "+$FORMAT")"
	[[ "$SECONDFRACTION" -gt 0 ]] && local NANOSECONDS="$(date '%n')"
	
	echo "${MAINDATE}${NANOSECONDS:0:${SECONDFRACTION}}"

} # datetag()
export -f datetag

################################################################################
function RunFunctionTestSuite() {
  # run the tests in this module
  local -ar Tests=( TestRemoveFromList_indirect TestFindInList TestFindLastInList TestIsInList TestInsertPath )
  local -i nErrors=0 nTests=0
  local Test
  for Test in "${Tests[@]}" ; do
    let ++nTests
    if ! "$Test" ; then
      ERROR "Test '${Test}' failed."
      let ++nErrors
    fi
  done
  if [[ $nErrors -gt 0 ]]; then
    ERROR "${nErrors} out of ${nTests} tests failed."
  fi
  return $nErrors
} # RunFunctionTestSuite()


################################################################################
