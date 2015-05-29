#!/bin/bash
#
# Date:   June 5th, 2011
# Author: Hamlet (_hamlet@libero.it)
#
# Run with '--help' for usage instructions.
# 

SCRIPTNAME="$(basename "$0")"

: ${DEFAULTFORMAT:="mp3"}

# program paths:
: ${lame:="lame"}

# - decoder paths and options
: ${oggdec:="oggdec"}
[[ -z "$oggdecargs" ]] && declare -a oggdecargs=( '--quiet' '-o' '-'  )

: ${ogginfo:="ogginfo"}
[[ -z "$ogginfoargs" ]] && declare -a ogginfoargs=()

: ${flacdec:="flac"}
[[ -z "$flacdecargs" ]] && declare -a flacdecargs=( '-d' '-c' )

: ${flacinfo:="metaflac"}
[[ -z "$flacinfoargs" ]] && declare -a flacinfoargs=( '--export-tags-to=-' )


function help() {
	cat <<-EOH
	Converts input audio files to a different format.
	
	Usage:  ${SCRIPTNAME}  [options] SourceFile [SourceFile ...]
	
	Options [default vaules in square brackets]:
	-f FORMAT , --format=FORMAT  ['${DEFAULTFORMAT}']
	   destination format
	-D DESTDIR , --destdir=DESTDIR  [current directory]
	   directory for converted files 
	-L LISTNAME , --listname=LISTNAME
	   creates a files list with all converted (or existing) files, with absolute path
	-F, --force
	   overwrite existing destination files
	-q QUALITY , --quality=QUALITY
	   quality index of the conversion (supported by: MP3 (lame))
	-P PRESET , --preset=PRESET
	   specify a configuration preset (supported by: MP# (lame))
	-T , --overridetrack
	   overrides the tag of track number to reflect the input files order
	-P , --prependtrack
	   prepends the track number to the converted file name (useful for sorting)
	EOH
} # help

function isFlagSet() {
	local VarName="$1"
	[[ -n "${!VarName//0}" ]]
} # isFlagSet


function isFunction() {
	local FuncName="$1"
	declare -F "$FuncName" >& /dev/null
} # isFunction


function isFlagUnset() {
	local VarName="$1"
	[[ -z "${!VarName//0}" ]]
} # isFlagUnset


function STDERR() {
	echo -e "$*" >&2
} # STDERR

function ERROR() {
	STDERR "ERROR: $*"
} # ERROR

function FATAL() {
	local Code="$1"
	shift
	STDERR "FATAL ERROR (${Code}): $*"
	exit $Code
} # FATAL

function LASTFATAL() {
	local Code="$?"
	[[ $Code != 0 ]] && FATAL "$Code" "$*"
} # LASTFATAL


function isDebugging() {
	[[ -z "$DEBUG" ]] && return 1
	local DebugLevel="${1:-1}"
	[[ "$DEBUG" -ge "$DebugLevel" ]]
} # isDebugging

function DBGN() {
	local -i DebugLevel="$1"
	shift
	isDebugging "$DebugLevel" && STDERR "DBG(${DebugLevel}) | $*"
} # DBGN

function DBG() {
	DBGN 1 "$*"
} # DBG


function DUMPVAR() {
	local DebugLevel="$1"
	local VarName="$2"
	[[ -z "$VarName" ]] && VarName="$1" && DebugLevel=1
	DBGN "$DebugLevel" "${VarName}='${!VarName}'"
} # DUMPVAR

function DUMPVARS() {
	local DebugLevel="$1"
	if isDebugging "$DebugLevel" ; then
		shift
		for VarName in "$@" ; do
			DUMPVAR "$DebugLevel" "$VarName"
		done
	fi
} # DUMPVARS


function AppendSlash() {
	local Dir="$1"
	echo "${Dir:+${Dir%/}/}"
} # AppendSlash


function isRelativePath() {
	local Path="$1"
	local DirName="$(dirname "$Path")"
	[[ "${DirName:0:1}" != '/' ]]
} # isRelativePath 


function ExpandPath() {
	# ExpandPath Path
	local Path="$1"
	
	[[ -z "$Path" ]] && return 1
	
	# start from the current directory, or an empty path if from root
	local Dir=""
	[[ "${Path:0:1}" != "/" ]] && Dir="$(pwd)"
	
	DBGN 4 "ExpandPath('${Path}') starting from '${Dir}'"
	
	local TheRest="$Path"
	while [[ -n "$TheRest" ]] ; do
		# pick the root-most part of the path which has not been processed yet:
		local BaseDir="${TheRest%%/*}"
		
		if [[ -z "$BaseDir" ]]; then
			DBGN 4 " - empty component"
			# it is empty? then a double '/' was encountered, just skip and go ahead
			true
		elif [[ "$BaseDir" == ".." ]]; then
			# parent directory: go up one from 
			Dir="$(dirname "$Dir")"
			DBGN 4 " - parent directory: now at '${Dir}'"
		elif [[ "$BaseDir" == "." ]]; then
			DBGN 4 " - current directory: still at '${Dir}'"
			true
		else
			Dir="${Dir%/}/${BaseDir}"
			DBGN 4 " - add directory '${BaseDir}': now at '${Dir}'"
		fi
		# let's see the elements left
		local NewRest="${TheRest#*/}"
		[[ "$TheRest" == "$NewRest" ]] && break
		TheRest="$NewRest"
		DBGN 5 "   (still '${TheRest}' to go)"
	done
	echo "$Dir"
	return 0
} # ExpandPath()

function ReadLink() {
	local Path="$1"
	readlink -f "$Path"
} # ReadLink


function AddFileToList() {
	# AddFileToList FilesList File
	local FilesList="$1"
	local FileName="$2"
	
	local TrackPadding="${#TOTALTRACKS}"
	local FileNo="$(printf '%0*d' "$TrackPadding" "$NINPUTTRACK")"
	
	local -i MyPID="$!"
	
	if [[ -z "$FilesList" ]] || [[ ! -w "$FilesList" ]] ; then
		DBGN 3 "Writing to file list skipped"
		return 1
	fi
	
	DBG "Adding '${FileName}' as '${FileNo}' to list '${FilesList}' (PID: ${MyPID})"
	
	# expand the file name
	local FilePath="$(ExpandPath "$FileName")"
	
	# lock the file list
	LockFile="${FilesList}-lock"
	
	local -i WaitLoop=0
	local -i WaitedTooMuch=600
	while [[ "$WaitLoop" -lt "$WaitedTooMuch" ]] && [[ -r "$LockFile" ]]; do
		local WaitTime="0.$((${RANDOM} % 100))"
		DBGN 2 "List file locked, waiting for $WaitTime seconds"
		sleep "$WaitTime"
		let ++WaitLoop
	done
	if [[ "$WaitLoop" -lt "$WaitedTooMuch" ]]; then
		echo "$MyPID" >> "$LockFile"
	else
		ERROR "Waited too much to write entry '${FileNo}' to file list, ignoring lock file"
		LockFile=""
	fi
	
	# add the line at the end of the file
	if isFlagSet FAKE ; then
		echo "Would add "${FilePath}" to '${FilesList}'"
	else
		echo "${FileNo}: ${FilePath}" >> "$FilesList"
	fi
	
	# unlock the file list
	[[ -n "$LockFile" ]] && [[ -w "$LockFile" ]] && rm -f "$LockFile"
	
	return 0
} # AddFileToList


function Execute() {
	local -a Command=( "$@" )
	if isFlagSet FAKE ; then
		STDERR "DRYRUN| ${Command[@]}"
	else
		"${Command[@]}"
	fi
} # Execute()


function SaveToFile() {
	local OutputFile="$1"
	if isFlagSet FAKE ; then
		STDERR "DRYRUN|   > '${OutputFile}'"
	else
		cat > "$OutputFile"
	fi
} # SaveToFile()


################################################################################
# conversion procedures

function flac_source() {
	local Source="$1"
	Execute "$flacdec" "${flacdecargs[@]}" "$Source" 
} # flac_source()

function ogg_source() {
	local Source="$1"
	Execute "$oggdec" "${oggdecargs[@]}" "$Source"
} # ogg_source()

function to_mp3() {
	Execute $lame \
  	  -h ${ConversionQualityIndex:+-V "$ConversionQualityIndex"} ${Preset:+--preset="$Preset"} \
	  ${TITLE:+--tt "$TITLE"} ${ARTIST:+--ta "$ARTIST"} ${ALBUM:+--tl "$ALBUM"} \
	  ${YEAR:+--ty "$YEAR"} ${COMMENT:+--tc "$COMMENT"} ${GENRE:+--tg "$GENRE"} \
	  ${TRACK:+--tn "$TRACK"} \
	  '-' '-'
} # to_mp3()


function Convert_ogg_to_mp3() {
	# Convert_ogg_to_mp3 SourcePath DestPath [FilesList]
	#
	#
	#
	local SourceFile="$1"
	local DestFile="$2"
	local FilesList="$3"
#	DBG "'${SourceFile}' -> '${DestFile}'"
	
	local TITLE="" ARTIST="" ALBUM="" DATE="" YEAR="" COMMENT="" GENRE="" TRACK="" AUTHORS=""
	
	# read the tags from source file
	TagsInfo="$(mktemp --tmpdir "${SCRIPTNAME%.sh}.XXXXXX" )"
	DBGN 2 "Using temporary file '${TagsInfo}' to collect tags information"
	
	"$ogginfo" "${ogginfoargs[@]}" "$SourceFile" > "$TagsInfo"
	
	isDebugging 3 && cat "$TagsInfo"
	
	TITLE="$(grep 'title=' "$TagsInfo" | sed 's/[[:space:]]*title=//')"
	ARTIST="$(grep 'artist=' "$TagsInfo" | sed 's/[[:space:]]*artist=//')"
	ALBUM="$(grep 'album=' "$TagsInfo" | sed 's/[[:space:]]*album=//')"
	GENRE="$(grep 'genre=' "$TagsInfo" | sed 's/[[:space:]]*genre=//')"
	DATE="$(grep 'date=' "$TagsInfo" | sed 's/[[:space:]]*date=//')"
	TRACK="$(grep 'tracknumber=' "$TagsInfo" | sed 's/[[:space:]]*tracknumber=//')"
	AUTHORS="$(grep 'authors=' "$TagsInfo" | sed 's/[[:space:]]*authors=//')"
	COMMENT="$(grep 'comment=' "$TagsInfo" | sed 's/[[:space:]]*comment=//')"
	
	DUMPVARS 3 TITLE ARTIST ALBUM GENRE DATE TRACK AUTHORS COMMENT
	
	[[ -n "$AUTHORS" ]] && COMMENT="Authors: ${AUTHORS}${COMMENT:+ ${COMMENT}}"
	YEAR="${DATE##*/}"
	
	isFlagSet OVERRIDETRACKS && TRACK="${NINPUTTRACK}/${TOTALTRACKS}"
	rm -f "$TagsInfo"
	
	isFlagSet QUIET || echo "$(date) - Converting '${SourceFile}' -> '${DestFile}'"
	# now do the job...
	ogg_source "$SourceFile" | to_mp3 | SaveToFile "$DestFile" || return $?
	
	[[ -n "$FilesList" ]] && AddFileToList "$FilesList" "$DestFile"
	
	return 0
} # Convert_ogg_to_mp3


function Convert_flac_to_mp3() {
	# Convert_flac_to_mp3 SourcePath DestPath [FilesList]
	#
	#
	#
	local SourceFile="$1"
	local DestFile="$2"
	local FilesList="$3"
#	DBG "'${SourceFile}' -> '${DestFile}'"
	
	local TITLE="" ARTIST="" ALBUM="" DATE="" YEAR="" COMMENT="" GENRE="" TRACK="" AUTHORS=""
	
	# read the tags from source file
	TagsInfo="$(mktemp --tmpdir "${SCRIPTNAME%.sh}.XXXXXX" )"
	DBGN 2 "Using temporary file '${TagsInfo}' to collect tags information"
	
	"$flacinfo" "${flacinfoargs[@]}" "$SourceFile" > "$TagsInfo"
	
	isDebugging 3 && cat "$TagsInfo"
	
	TITLE="$(grep 'TITLE=' "$TagsInfo" | sed 's/[[:space:]]*TITLE=//')"
	ARTIST="$(grep 'ARTIST=' "$TagsInfo" | sed 's/[[:space:]]*ARTIST=//')"
	ALBUM="$(grep 'ALBUM=' "$TagsInfo" | sed 's/[[:space:]]*ALBUM=//')"
	GENRE="$(grep 'GENRE=' "$TagsInfo" | sed 's/[[:space:]]*GENRE=//')"
	DATE="$(grep 'YEAR=' "$TagsInfo" | sed 's/[[:space:]]*DATE=//')"
	TRACK="$(grep 'TRACKNUMBER=' "$TagsInfo" | sed 's/[[:space:]]*TRACKNUMBER=//')"
	AUTHORS="$(grep 'AUTHORS=' "$TagsInfo" | sed 's/[[:space:]]*AUTHORS=//')"
	COMMENT="$(grep 'COMMENT=' "$TagsInfo" | sed 's/[[:space:]]*COMMENT=//')"
	
	DUMPVARS 3 TITLE ARTIST ALBUM GENRE DATE TRACK AUTHORS COMMENT
	
	[[ -n "$AUTHORS" ]] && COMMENT="Authors: ${AUTHORS}${COMMENT:+ ${COMMENT}}"
	
	isFlagSet OVERRIDETRACKS && TRACK="${NINPUTTRACK}/${TOTALTRACKS}"
	rm -f "$TagsInfo"
	
	isFlagSet QUIET || echo "$(date) - Converting '${SourceFile}' -> '${DestFile}'"
	# now do the job...
	flac_source "$SourceFile" | to_mp3 | SaveToFile "$DestFile" || return $?
	
	[[ -n "$FilesList" ]] && AddFileToList "$FilesList" "$DestFile"
	
	return 0
} # Convert_flac_to_mp3



################################################################################
# parameters parser
Format="$DEFAULTFORMAT"

declare -a InputParams
declare -i NInputParams=0

declare -i NoMoreOptions=0

for (( iParam = 1 ; iParam <= $# ; ++iParam )); do
	Param="${!iParam}"
	if isFlagUnset NoMoreOptions && [[ "${Param:0:1}" == '-' ]]; then
		case "$Param" in
			( '-h' | '--help' | '-?' )
				DoHelp=1
				;;
			( '-f' | '--format='* )
				if [[ "$Param" == '-f' ]]; then
					let ++iParam
					Format="${!iParam}"
				else
					Format="${Param#--format=}"
				fi
				;;
			( '-D' | '--destdir='* )
				if [[ "$Param" == '-D' ]]; then
					let ++iParam
					DestDir="${!iParam}"
				else
					DestDir="${Param#--destdir=}"
				fi
				;;
			( '-L' | '--listname='* )
				if [[ "$Param" == '-L' ]]; then
					let ++iParam
					DestList="${!iParam}"
				else
					DestList="${Param#--listname=}"
				fi
				;;
			( '-f' | '--fake' )
				FAKE=1
				;;
			( '-F' | '--force' )
				FORCE=1
				;;
			( '-T' | '--overridetrack' )
				OVERRIDETRACKS=1
				;;
			( '-P' | '--prependtrack' )
				PREPENDTRACK=1
				;;
			( '-q' | '--quality='* )
				if [[ "$Param" == '-q' ]]; then
					let ++iParam
					ConversionQualityIndex="${!iParam}"
				else
					ConversionQualityIndex="${Param#--quality=}"
				fi
				;;
			( '-P' | '--preset='* )
				if [[ "$Param" =~ -. ]]; then
					let ++iParam
					Preset="${!iParam}"
				else
					Preset="${Param#--*=}"
				fi
				;;
			( '-d' | '--debug'* )
				if [[ "$Param" == '-d' ]] || [[ "$Param" == '--debug' ]]; then
					let ++iParam
					if [[ "${!iParam:0:1}" == '-' ]]; then
						let --iParam
						DEBUG=1
					else
						DEBUG="${!iParam}"
					fi
				else
					DEBUG="${Param#--debug=}"
				fi
				;;
			( '-' | '--' )
				NoMoreOptions=1
				;;
			( * )
				if isFlagSet DoHelp ; then
					ERROR "option '${Param%%=*}' unknown."
				else
					FATAL 1 "option '${Param%%=*}' unknown (use '--help' for instructions)."
				fi
				;;
		esac
	else
		InputParams[NInputParams++]="$Param"
	fi
done

isFlagSet DoHelp && help && exit

################################################################################
# remove dot from format
[[ "${Format:0:1}" == "." ]] && Format="${Format#.}"
DestDir="$(AppendSlash "$DestDir")"

DBG "Output directory: '${DestDir}'"
isFlagSet FAKE || [[ -z "$DestDir" ]] || mkdir -p "$DestDir"

declare -i nErrors=0
declare -i nSuccess=0

# expand input parameters
declare -a Sources
declare -i NSources=0

for InputParam in "${InputParams[@]}" ; do
	# special treatment for lists
	if [[ "${InputParam%.list}" != "$InputParam" ]] || [[ "${InputParam%.m3u}" != "$InputParam" ]]; then
		InputList="$InputParam"
		if [[ ! -r "$InputList" ]]; then
			ERROR "Can't read input files list '${InputList}'"
			let ++nErrors
			continue
		fi
		
		InputListDir="$(dirname "$InputList")"
		
		declare -i NFilesInList=0
		while read Line ; do
			if [[ -z "$Line" ]] || [[ "${Line:0:1}" == "#" ]]; then 
				# comment!
				continue
			fi
			
			DBGN 3 "Read '${Line}' from file list"
			FileName="$Line"
			FilePath=""
			if [[ ! -r "$FileName" ]] && isRelativePath "$FileName" ; then
				FilePath="${InputListDir}/${FileName}"
			fi
			# FilePath can legally not exist!
			[[ -r "$FilePath" ]] || FilePath="$FileName"
			
			Sources[NSources++]="$FilePath"
			DBG "Adding '${FilePath}' (from a list) to the sources"
			let ++NFilesInList
		done < "$InputList"
		DBG "$NFilesInList files from file list '${InputList}' added"
	else
		DBG "Adding '${InputParam}' to the sources"
		Sources[NSources++]="$InputParam"
	fi
done

[[ "${#Sources[@]}" == 0 ]] && FATAL 1 "No valid sources specified (use \`${SCRIPTNAME} --help\` for instructions)."


isFlagSet FORCE && isFlagUnset FAKE && [[ -n "$DestList" ]] && rm -f "$DestList"
if isFlagUnset FAKE && [[ -n "$DestList" ]]; then
	touch "$DestList"
	LASTFATAL "Can't write on destination list '${DestList}'"
fi

declare -i TOTALTRACKS=$NSources
declare -i NINPUTTRACK=1

declare -i TrackPadding="${#TOTALTRACKS}"

################################################################################
# loop on sources
for SourceFile in "${Sources[@]}" ; do
	
	if [[ ! -r "$SourceFile" ]]; then
		ERROR "File '${SourceFile}' not found."
		let ++nErrors
		continue
	fi
	
	SourceFormat="${SourceFile##*.}"
	
	ConvertProc="Convert_${SourceFormat}_to_${Format}"
	
	isFunction "$ConvertProc" || FATAL 1 "Don't know how to convert '${SourceFile}' (${SourceFormat}) to ${Format}"
	
	SourceName="$(basename "${SourceFile%.${SourceFormat}}")"
	DestName="${SourceName}.${Format}"
	isFlagSet PREPENDTRACK && DestName="$(printf '%0*d' "$TrackPadding" "$NINPUTTRACK")_${DestName}"
	DestFile="${DestDir}${DestName}"
	
	if [[ -r "$DestFile" ]]; then
		RealSourceFile="$(ReadLink "$SourceFile")"
		RealDestFile="$(ReadLink "$DestFile")"
		if [[ "$RealDestFile" == "$RealSourceFile" ]]; then
			ERROR "Source file '${SourceFile}' and destination file '${DestFile}' are the same."
			let ++nErrors
			continue
		fi
		if isFlagSet FORCE ; then
			DBG "Removing existing destination file '${DestFile}'"
			rm -f "$DestFile"
		else
			ERROR "Destination file '${DestFile}' (for '${SourceFile}') already exists."
			AbsoluteDestFile="$(ExpandPath "$DestFile")"
			if isFlagSet FAKE && [[ -n "$DestList" ]] ; then
				echo "Would add "${AbsoluteDestFile}" to '${DestList}'"
			else
				[[ -w "$DestList" ]] && echo "$AbsoluteDestFile" >> "$DestList"
			fi
			let ++nErrors
			continue
		fi
	fi
	
	"$ConvertProc" "$SourceFile" "$DestFile" "$DestList" &
	ConvertPID="$!"
	DBGN 1 "Converting '${SourceFile}' to '${DestFile}' by '${ConvertProc}' (PID=${ConvertPID})"
	wait "$ConvertPID"
	res=$?
	if [[ $res != 0 ]]; then
		ERROR "conversion of '${SourceFile}' (${SourceFormat}) to ${Format} failed with code ${res}!"
		let ++nErrors
		continue
	fi
	
	let ++nSuccess
	let ++NINPUTTRACK
done

#rearrange the files list
if [[ -w "$DestList" ]] && isFlagUnset FAKE; then
	DBGN 1 "Finalizing files list"
	TempFileList="$(mktemp --tmpdir "${SCRIPTNAME%.sh}-filelist.XXXXXX" )"
	DBGN 3 "Temporary file: '${TempFileList}'"
	if isDebugging 4 ; then
		DBG '--- unsorted list ----'
		cat "$DestList"
		DBG '------ end list ------'
	fi
	sort -g "$DestList" > "$TempFileList"
	sed -e 's/^[[:digit:]]+: //' "$TempFileList" | grep -v '^[[:space:]]*$' > "$DestList"
	rm -f "$TempFileList"
fi

echo "$(date) - finished."
[[ $nSuccess -gt 0 ]] && [[ $nErrors == 0 ]]
