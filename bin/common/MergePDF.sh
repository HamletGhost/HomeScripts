#!/usr/bin/env bash
#
# Usage:  MergePDF.sh  OutputFile SourceFile SourceFile [...]
#

declare -a gs=( 'gs' )

function Exec() {
	local -a Cmd=( "$@" )
	echo "${Cmd[@]}"
	"${Cmd[@]}"
} # Exec()

declare OutputFile="$1"
shift
declare -a SourceFiles=( "$@" )

if [[ -z "$OutputFile" ]]; then
  echo "Please specify a file name for the merged document." >&2
  exit 1
fi

Exec "${gs[@]}" -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile="$OutputFile" "${SourceFiles[@]}"

