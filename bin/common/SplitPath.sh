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
	
	Usage:  SplitPath.sh Spec [Spec ...]
	
	Options can be inserted anywhere and will affect only the following arguments:
	 -v --varname Spec is a variable name (default)
	 -e --value   Spec is directly a value
	 -sSEP        use SEP as separator from now on (default: ':')
	 -h -? --help print this help message
	 --           no more options
	EOH
} # help()


declare -i NoMoreOptions=0
declare Mode="var"

for Arg in "$@" ; do
	# check if it's a mode option
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
			( "-s"* )
				SEP="${Arg#-s}"
				continue
				;;
			( "-h" | '-?' | '--help' )
				help
				continue
				;;
			( "--" )
				NoMoreOptions=1
				continue
				;;
		esac
	fi
	
	if [[ "$Mode" == 'var' ]]; then
		case "$Arg" in
			( '@lib' ) VarName='LD_LIBRARY_PATH' ;;
			( '@bin' ) VarName='PATH' ;;
			( '@man' ) VarName='MANPATH' ;;
		esac
		Value="${!VarName}"
	else
		Value="$Arg"
	fi
	
	[[ -z "$Value" ]] && continue
	tr "$SEP" "\n" <<< "$Value"
done

