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
	
	
	export FUNCTIONS_SH_LOADED=1
	
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

function FATAL() {
	local Code="$1"
	shift
	STDERR "${FatalColor}Fatal error (${Code}): $*${ResetColor}"
	exit $Code
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


function InsertPath() {
	#
	# InsertPath [options] VarName Path [Path ...]
	#
	# Insert paths to a list of paths separated by a separator in VarName.
	# The resulting list is printed out.
	#
	# Options:
	# -s SEP     specify the separation string (default: ':')
	# -1 (number!) don't allow for duplicate items (existing and added)
	# -m         allow for duplicate items (default)
	# -a         append (default)
	# -p         prepend
	# -e         add only if existing
	# -d         add only if existing directory
	#
	local Option Separator=':' Prepend=0 AllowDuplicates=1 Move=0
	local -a Checks
	OPTIND=1
	while getopts "ed1Dmaps:-" Option ; do
		case "$Option" in
			( 'e' | 'd' ) Checks=( "${Checks[@]}" "-${Option}" ) ;;
			( '1' ) AllowDuplicates=0 ;;
			( 'D' ) AllowDuplicates=1 ;;
			( 'm' ) Move=1 ;;
			( 'a' ) Prepend=0 ;;
			( 'p' ) Prepend=1 ;;
			( 's' ) Separator="$OPTARG" ;;
			( '-' ) break ;;
		esac
	done
	shift $((OPTIND - 1))
	
	local VarName="$1"
	shift
	
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
			
			[[ "${#WrittenItems[@]}" == 0 ]] || echo -n "$Separator"
			echo -n "$Item"
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
			
			[[ "${#WrittenItems[@]}" == 0 ]] || echo -n "$Separator"
			echo -n "$KnownItem"
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
			
			[[ "${#WrittenItems[@]}" == 0 ]] || echo -n "$Separator"
			echo -n "$KnownItem"
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
			
			[[ "${#WrittenItems[@]}" == 0 ]] || echo -n "$Separator"
			echo -n "$Item"
			WrittenItems=( "${WrittenItems[@]}" "$Item" )
		done
	fi # prepend/append
	
	echo
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
		[[ "${#KnownItems[@]}" == 0 ]] || echo -n "$Separator"
		
		echo -n "$ExistingItem"
		
		KnownItems=( "${KnownItems[@]}" "$ExistingItem" )
	done # ( while )
	echo
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
	eval "export ${VarName}=\"$(DeletePathSep "$@" )\""
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
		[[ "${#KnownItems[@]}" == 0 ]] || echo -n "$Separator"
		
		echo -n "$Item"
		
		KnownItems=( "${KnownItems[@]}" "$Item" )
	done # ( while )
	echo
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

