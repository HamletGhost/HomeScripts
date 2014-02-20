#!/bin/sh
#
#
#

SCRIPTNAME="$(basename "$0")"

: ${gs:="gs"}


function isFlagSet() {
	local VarName="$1"
	[[ -n "${!VarName//0}" ]]
} # isFlagSet()


function help() {
	cat <<-EOH
	Extracts the specified range of pages from a PDF file.

	Usage:  ${SCRIPTNAME}  [options] SourceFile FirstPage[-LastPage] [OutputFile]

	If LastPage is not specified, only one page is extracted.
	If OutputFile is not specified, it will based on SourceFile name.

	Options:
	--force , -f
	    if the output file name is not specified, overwrites the output file if it exists
	EOH
}

function STDERR() {
	echo "$*" >&2
} # STDERR

function FATAL() {
	local Code="$1"
	shift
	STDERR "Fatal error ($Code): $*"
	exit $Code
} # FATAL()


# parameters loop
declare -a Params
declare -i NParams
declare -i NoMoreParams=0
for Param in "$@" ; do
	if [[ "${Param:0:1}" != '-' ]] || isFlagSet NoMoreParams ; then
		Params[NParams++]="$Param"
	else
		case "$Param" in
			( "-h" | "--help" | "-?" )
				DoHelp=1
				;;
			( "--force" | "-f" )
				FORCE=1
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
PagesRange="${Params[1]}"
OutputFile="${Params[2]}"

[[ -r "$SourceFile" ]] || FATAL 2 "Can't find source file '${SourceFile}'."

SourceName="$(basename "$SourceFile")"
declare -i FirstPage="${PagesRange%-*}"
declare -i LastPage="${PagesRange#*-}"

if [[ "$FirstPage" == "$LastPage" ]]; then
	Tag="page"
	PageLabel="$FirstPage"
else
	Tag="pages"
	PageLabel="$PagesRange"
fi

if [[ -z "$OutputFile" ]]; then
	BaseName="${SourceName%.pdf}"
	Extension="${SourceName#${BaseName}}"
	OutputFile="${BaseName}${Tag:+_${Tag}${PageLabel}}.pdf"
	isFlagSet FORCE && rm -f "$OutputFile"
	[[ -r "$OutputFile" ]] && FATAL 1 "Output file '${OutputFile}' already exist. Nothing done."
fi

$gs -sDEVICE=pdfwrite -dNOPAUSE -dBATCH -dSAFER -dFirstPage="$FirstPage" -dLastPage="$LastPage" -sOutputFile="$OutputFile" "$SourceFile" > /dev/null
echo "'${OutputFile}' created from ${Tag} ${PageLabel} of '${SourceFile}'."
