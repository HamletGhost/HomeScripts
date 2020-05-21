#!/usr/bin/env bash
#
# Extracts single pages from a PDF file.
# Run with `--help` for usage instrutcions.
#

SCRIPTNAME="$(basename "$0")"

: ${gs:="gs"}

[[ -z "$pdfinfo" ]] && pdfinfo=( "pdfinfo" )

function isFlagSet() {
	local VarName="$1"
	[[ -n "${!VarName//0}" ]]
} # isFlagSet()


function help() {
	cat <<-EOH
	Extracts the specified range of pages from a PDF file.

	Usage:  ${SCRIPTNAME}  [options] SourceFile FirstPage[-[LastPage]]

	If LastPage is not specified, only one page is extracted.

	Options:
	--output=OUTPUTFILE [SourceFile]
	    base the name of output file(s) on OUTPUTFILE
	--single , -S
	    splits the specified range in single PDF pages
	--force , -f
	    if the output file name is not specified, overwrites the output file if it exists
	EOH
} # help()

function STDERR() { echo "$*" >&2 ; }

function FATAL() {
	local Code="$1"
	shift
	STDERR "Fatal error ($Code): $*"
	exit $Code
} # FATAL()


function PDFpages() {
  local File="$1"
  "${pdfinfo[@]}" "$File" | grep -E '^Pages:' | sed -e 's/^Pages: *//g'
} # PDFpages()


function ExtractPages() {
  # Usage:  ExtractPages SourceFile OutputFile FirstPage LastPage
  local SourceFile="$1"
  local OutputFile="$2"
  local -i FirstPage="$3"
  local LastPage="${4:-${FirstPage}}"

  [[ "$LastPage" == '-' ]] && LastPage="$(PDFpages "$SourceFile")"

  local SourceName="$(basename "$SourceFile")"
  
  local TagType PageLabel
  if [[ "$FirstPage" == "$LastPage" ]]; then
    TagType="page"
    PageLabel="${FirstPage}"
  else
    TagType="pages"
    PageLabel="${FirstPage}-${LastPage}"
  fi
  local Tag="${TagType}${PageLabel}"
  
  local OutputDir=""
  if [[ -d "$OutputFile" ]] || [[ "${OutputFile:-1}" == '/' ]]; then
    # this is a directory
    OutputDir="$OutputFile"
    OutputFile=""
  fi

  if [[ -z "$OutputFile" ]]; then
    BaseName="${SourceName%.pdf}"
    Extension="${SourceName#${BaseName}}"
    OutputFile="${OutputDir:+${OutputDir}/}${BaseName}${Tag:+_${Tag}}.pdf"
    isFlagSet FORCE && rm -f "$OutputFile"
    [[ -r "$OutputFile" ]] && FATAL 1 "Output file '${OutputFile}' already exist. Nothing done."
  fi
  
  [[ -n "$OutputDir" ]] && mkdir -p "$OutputDir"
  $gs -sDEVICE=pdfwrite -dNOPAUSE -dBATCH -dSAFER -dFirstPage="$FirstPage" -dLastPage="$LastPage" -sOutputFile="$OutputFile" "$SourceFile" > /dev/null
  local res=$?
  [[ $res == 0 ]] && echo "'${OutputFile}' created from ${TagType} ${PageLabel} of '${SourceFile}'."
  return $?
} # ExtractPages()


###############################################################################
# parameters loop
declare -a Params
declare -i NParams
declare -i NoMoreParams=0
for Param in "$@" ; do
	if [[ "${Param:0:1}" != '-' ]] || isFlagSet NoMoreParams ; then
		Params[NParams++]="$Param"
	else
		case "$Param" in
			( "--single" | "-S" ) DoSinglePages=1 ;;
			( "--output="* )      OutputFile="${Param#--*=}" ;;
			( "--force" | "-f" )  FORCE=1 ;;
			( "-h" | "--help" | "-?" )
				DoHelp=1
				;;
			( "-" | "--" )
				NoMoreParams=1
				;;
			( * )
				FATAL 1 "Unsupported option - '${Param}'"
				;;
		esac
	fi
done

if [[ $NParams == 0 ]] || isFlagSet DoHelp ; then
	help
	exit
fi

SourceFile="${Params[0]}"
unset Params[0]
declare -a InputRanges=( "${Params[@]}" )

[[ -r "$SourceFile" ]] || FATAL 2 "Can't find source file '${SourceFile}'."

#
# Expand the ranges
#
declare -a Ranges
for PagesRange in "${InputRanges[@]}" ; do
	if isFlagSet DoSinglePages ; then
		if [[ "$PagesRange" =~ - ]]; then
			Ranges=( "${Ranges[@]}" $(seq ${PagesRange/-/ }) )
		else
			Ranges=( "${Ranges[@]}" "$PagesRange" )
		fi
	else
		Ranges=( "${Ranges[@]}" "$PagesRange" )
	fi
done

#
# process the ranges
#
declare -i nErrors=0
for PagesRange in "${Ranges[@]}" ; do
	declare -i FirstPage="${PagesRange%-*}"
	declare LastPage="${PagesRange#*-}"
	[[ -z "$LastPage" ]] && LastPage='-'

	ExtractPages "$SourceFile" "$OutputFile" "$FirstPage" "$LastPage"
	res=$?
	[[ $res != 0 ]] && let ++nErrors
done

if [[ $nErrors != 0 ]]; then
	STDERR "${nErrors} errors while extracting ${#Ranges[@]} page ranges from '${SourceFile}'"
	exit $res
fi
echo "Extracted ${#Ranges[@]} page ranges from '${SourceFile}'"

