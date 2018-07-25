#!/usr/bin/env bash

SCRIPTNAME="$(basename "$0")"

#################################################################################
declare -r pandoc='pandoc'
declare -a pandocOpt

#################################################################################
function CompileToPDF() {
	local -r InputFile="$1"
	local -r OutputFile="${InputFile%.md}.pdf"
	
	echo "Compiling '${InputFile}' => '${OutputFile}'..."
	$pandoc "${pandocOpt[@]}" -o "$OutputFile" "$InputFile"
	
} # CompileToPDF()

#################################################################################
declare -a InputFiles=( "$@" )
declare -i nInputs="${#InputFiles[@]}"

if [[ $nInputs == 0 ]]; then
	echo "Usage:  ${SCRIPTNAME}  MarkdownFile [MarkdownFile ...]"
	exit
fi

declare -i nErrors=0

for InputFile in "${InputFiles[@]}" ; do
	CompileToPDF "$InputFile"
	res=$?
	if [[ $res != 0 ]]; then
		echo "ERROR: compilation of '${InputFile}' failed with exit code ${res}!!" >&2
		let ++nErrors
		continue
	fi
done

if [[ $nErrors -gt 0 ]]; then
	[[ $nInputs -gt 1 ]] && echo "${nErrors}/${nInputs} failures found!"
	exit 1
fi

[[ $nInputs -gt 1 ]] && echo "All ${nInputs} files were successfully processed."
exit

