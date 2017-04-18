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


# functions are always redefined
function STDERR() {
	echo -e "$*" >&2
} # STDERR()

function INFO() {
	STDERR "${InfoColor}$*${ResetColor}"
} # INFO()

function WARN() {
	STDERR "${WarnColor}Warning: $*${ResetColor}"
} # WARN()

function ERROR() {
	STDERR "${ErrorColor}Error: $*${ResetColor}"
} # ERROR()

function CRITICAL() {
	# A version of FATAL for functions expected to be called from command line.
	# It only prints an error message. FATAL-like usage is envisioned as:
	#     
	#     CRITICAL 2 "File not found!"
	#     return $?
	#     
	# 
	local Code="$1"
	shift
	STDERR "${FatalColor}Fatal error (${Code}): $*${ResetColor}"
	return $Code
} # CRITICAL()

function FATAL() {
	CRITICAL "$@"
	exit $?
} # FATAL()

function LASTFATAL() {
	local Code="$?"
	[[ "$Code" != 0 ]] && FATAL $Code $*
} # LASTFATAL()

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

function isDebugging() {
	isFlagSet DEBUG
}

function DBG() {
	isDebugging && STDERR "${DebugColor}DBG| $*${ResetColor}"
} # DBG()

function DBGN() {
	# DBGN DebugLevel Debug Message
	# Debug message is printed only if current DEBUG level is bigger or equal to
	# DebugLevel.
	local -i DebugLevel="$1"
	shift
	[[ -n "$DEBUG" ]] && [[ "$DEBUG" -ge "$DebugLevel" ]] && DBG "$*"
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


function InsertPath() {
	#
	# See "DoHelp" section in the code for usage directions.
	#
	local Option Separator=':' Prepend=0 AllowDuplicates=1 Move=0 DoHelp=0
	local -a Checks
	OPTIND=1
	while getopts "ed1Dmaps:h-" Option ; do
		case "$Option" in
			( 'e' | 'd' ) Checks=( "${Checks[@]}" "-${Option}" ) ;;
			( '1' ) AllowDuplicates=0 ;;
			( 'D' ) AllowDuplicates=1 ;;
			( 'm' ) Move=1 ;;
			( 'a' ) Prepend=0 ;;
			( 'p' ) Prepend=1 ;;
			( 's' ) Separator="$OPTARG" ;;
			( 'h' ) DoHelp=1 ;;
			( '-' ) break ;;
		esac
	done
	shift $((OPTIND - 1))
	
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
			-1 (number!)
			    don't allow for duplicate items (existing and added): if an element
			    is already present, it is not added again
			-m
			    don't allow for duplicate items (existing and added): if the Path is
			    already present, it is moved to the beginning (prepend mode) or end
			    (append mode)
			-a
			    append (default)
			-p
			    prepend
			-e
			    add a Path only if it exists
			-d
			    add a Path only if it is an existing directory
			-h
			    print this help
			
		EOH
		return 0
	fi
	
	local -a KnownItems WrittenItems
	local OldIFS="$IFS"
	IFS="$Separator"
	read -a KnownItems <<< "${!VarName}"
	IFS="$OldIFS"
	
	if isFlagSet Prepend ; then
		
		local Check
		
		# first write the new items
		for Item in "$@" ; do
			
			for Check in "${Checks[@]}" ; do
				test "$Check" "$Item" || continue 2
			done
			
			if isFlagUnset AllowDuplicates ; then
				local WrittenItem
				for WrittenItem in "${WrittenItems[@]}" ; do
					[[ "$Item" == "$WrittenItem" ]] && continue 2 # go to the next item
				done
			fi
			
			local isKnown=0
			local KnownItem
			for KnownItem in "${KnownItems[@]}" ; do
				[[ "$Item" == "$KnownItem" ]] && isKnown=1 && break
			done
			
			isFlagSet isKnown && isFlagUnset Move && continue
			
			[[ "${#WrittenItems[@]}" == 0 ]] || printf '%s' "$Separator"
			printf '%s' "$Item"
			WrittenItems=( "${WrittenItems[@]}" "$Item" )
		done # items
		local -i nAddedItems=${#WrittenItems[@]}
		
		# now write the items which were there already
		for KnownItem in "${KnownItems[@]}" ; do
			
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
		
		# first write the items which are there already
		for KnownItem in "${KnownItems[@]}" ; do
			if isFlagUnset AllowDuplicates ; then
				local WrittenItem
				for WrittenItem in "${WrittenItems[@]}" ; do
					[[ "$WrittenItem" == "$KnownItem" ]] && continue 2
				done
			fi
			
			if isFlagSet Move ; then
				# check if it will be written later
				local Item
				for Item in "$@" ; do
					[[ "$Item" == "$KnownItem" ]] && continue 2
				done
			fi
			
			[[ "${#WrittenItems[@]}" == 0 ]] || printf '%s' "$Separator"
			printf '%s' "$KnownItem"
			WrittenItems=( "${WrittenItems[@]}" "$KnownItem" )
		done
		
		# then the new ones
		local Item
		for Item in "$@" ; do
			for Check in "${Checks[@]}" ; do
				test "$Check" "$Item" || continue 2
			done
			
			if isFlagUnset AllowDuplicates ; then
				local WrittenItem
				for WrittenItem in "${WrittenItems[@]}" ; do
					[[ "$WrittenItem" == "$Item" ]] && continue 2
				done
			fi
			
			if isFlagUnset Move ; then
				local KnownItem
				for KnownItem in "${KnownItems[@]}" ; do
					[[ "$Item" == "$KnownItem" ]] && continue 2
				done
			fi
			
			[[ "${#WrittenItems[@]}" == 0 ]] || printf '%s' "$Separator"
			printf '%s' "$Item"
			WrittenItems=( "${WrittenItems[@]}" "$Item" )
		done
	fi # prepend/append
	
	printf "\n"
	return 0
} # InsertPath()


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
	while getopts "ed1Dmaps:-" Option ; do
		[[ "$Option" == "-" ]] && break
	done
	
	local VarName="${!OPTIND}"
	eval "export ${VarName}=\"$(InsertPath "$@" )\""
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
		Path="${Path:0: -1}"
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
