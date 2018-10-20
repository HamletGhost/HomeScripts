#!/bin/bash
#
# Usage:  SplitPath.sh Spec [Spec ...]
# 
# Options can be inserted anywhere and will affect only the following arguments:
#  -v     Spec is a variable name (default)
#  -e     Spec is directly a value
#  -sSEP  use SEP as separator from now on (default: ':')
#  --     no more options
#

: ${SEP:=":"}

function help() {
	cat <<-EOH
	Prints the paths in the arguiments, one per line.
	
	Usage:  SplitPath.sh [Spec ...]
	
	Options can be inserted anywhere and will affect only the following arguments:
	 -v --varname Spec is a variable name (default)
	 -e --value   Spec is directly a value
	 -i --stdin   immediately read specs from standard input
	 -sSEP        use SEP as separator from now on (default: ':')
	 -h -? --help print this help message
	 --           no more options
	
	If a Spec is an empty string, it is interpreted as `--stdin` option.
	EOH
} # help()


function ParseVariableAlias() {
	local Arg="$1"
	local VarName
	case "$Arg" in
		( '@lib' ) VarName='LD_LIBRARY_PATH' ;;
		( '@bin' ) VarName='PATH' ;;
		( '@man' ) VarName='MANPATH' ;;
		( '@ups' ) VarName='PRODUCTS' ;;
		( * )      VarName="$Arg" ;;
	esac
	echo "$VarName"
} # ParseVariableAlias()


function ReadItems() {
	local -a Args=( "$@" )
	local Arg
	for Arg in "${Args[@]}" ; do
		if [[ -z "$Arg" ]]; then
			cat # transfer from standard input
		else
			echo "$Arg"
		fi
	done
} # ReadItems()


function SplitElements() {
	local Value="$1"
	[[ -n "$Value" ]] && tr "$SEP" "\n" <<< "$Value"
} # SplitElements()


function PerformSplitting() {
	local Mode="$1"
	local Arg="$2"
	ReadItems "$Arg" | while read Item ; do
		if [[ "$Mode" == 'var' ]]; then
			VarName="$(ParseVariableAlias "$Item")"
			Value="${!VarName}"
		else
			Value="$Item"
		fi
		SplitElements "$Value"
	done
} # PerformSplitting()


declare -i NoMoreOptions=0
declare Mode="var"

for Arg in "$@" ; do
	# check if it is a mode option
	if [[ "${Arg:0:1}" == '-' ]] && [[ $NoMoreOptions == 0 ]]; then
		case "$Arg" in
			( '-v' | '--var' | '--varname' )
				Mode="var"
				continue
				;;
			( '-e' | '--value' )
				Mode="val"
				continue
				;;
			( '-s'* )
				SEP="${Arg#-s}"
				continue
				;;
			( '-i' | '--stdin' )
				# set the argument to empty, and let it be parsed that way
				Arg=''
				;;
			( '-h' | '-?' | '--help' )
				help
				continue
				;;
			( '--' )
				NoMoreOptions=1
				continue
				;;
		esac
	fi
	PerformSplitting "$Mode" "$Arg"
done

