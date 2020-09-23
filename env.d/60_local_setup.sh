#!/bin/bash

function ConfigureProgramDir() {
	# adds one directory to a specified variable, if that directory exists.
	OPTIND=1
	local Option
	local PriorityOpt='-a' # append
	local -i Quiet=0
	while getopts 'apq' Option ; do
		case "$Option" in
			( 'p' | 'a' ) PriorityOpt="-${Option}" ;; # prepend or append
			( 'q' ) Quiet=1 ;;
			( * ) ;;
		esac
	done
	shift $((OPTIND - 1))
	local VarName="$1"
	local Dir="$2"
	[[ -d "$Dir" ]] || return 1
	isFlagSet Quiet || echo "Adding '${Dir}' to ${VarName}"
	AddToPath "$PriorityOpt" "$VarName" "$Dir"
	return 0
} # ConfigureProgramDir()


function ConfigureProgramDirs() {
	# adds the standard POSIX directories to the standard POSIX variables
	# for each of the specified directories
	OPTIND=1
	local -i DoHelp=0 Priority=0 Quiet=0
	local Option
	while getopts 'pqnh?' Option ; do
		case "$Option" in
			( 'h' | '?' ) DoHelp=1 ;;
			( 'p' ) Priority=1 ;;
			( 'q' ) Quiet=1 ;;
			( 'n' ) AcceptFailure=1 ;;
			( * ) return 1 ;;
		esac
	done
	shift $((OPTIND - 1))
	
	if [[ "$DoHelp" != 0 ]]; then
		cat <<-EOH
		Adds the standard POSIX subdirectories to the standard POSIX variables.
		
		Options:
		    -p
		         priority: adds the directories in the place of maximum priority
		    -n
		         if a directory does not exist, it is just ignored
		    -q
		         does not print information messages (errors are still printed)
		    -h , -?
		         show this help message
		
		EOH
		return 0
	fi
	
	local Dir
	local -i nErrors=0
	local -a Options
	isFlagSet Quiet && Options+=( '-q' )
	for Dir in "$@" ; do
		if [[ ! -d "$Dir" ]]; then
			if isFlagUnset AcceptFailure ; then
				ERROR "${FUNCNAME}: '${Dir}' is not a directory!"
				let ++nErrors
			elif isFlagUnset Quiet ; then
				WARN "${FUNCNAME}: '${Dir}' is not a directory: ignored."
			else
				DBG "${FUNCNAME}: '${Dir}' is not a directory: ignored."
			fi
			continue
		fi
	#	echo "Try '${Dir}'"
	
		local PriorityOpt='-a' # append to the end, low priority
		[[ "$Priority" != 0 ]] && PriorityOpt='-p' # prepend, high priority
			
		local -i nConfigured=0
		ConfigureProgramDir "${Options[@]}" "$PriorityOpt" PATH "${Dir}/bin" && let ++nConfigured

		if ConfigureProgramDir "${Options[@]}" "$PriorityOpt" LD_LIBRARY_PATH "${Dir}/lib64" ; then
			let ++nConfigured
			ConfigureProgramDir "${Options[@]}" "$PriorityOpt" PKG_CONFIG_PATH "${Dir}/lib64/pkgconfig" && let ++nConfigured
		elif ConfigureProgramDir LD_LIBRARY_PATH "${Dir}/lib32" ; then
			let ++nConfigured
			ConfigureProgramDir "${Options[@]}" "$PriorityOpt" PKG_CONFIG_PATH "${Dir}/lib32/pkgconfig" && let ++nConfigured
		elif ConfigureProgramDir LD_LIBRARY_PATH "${Dir}/lib" ; then
			let ++nConfigured
			ConfigureProgramDir "${Options[@]}" "$PriorityOpt" PKG_CONFIG_PATH "${Dir}/lib/pkgconfig" && let ++nConfigured
		fi
		
		ConfigureProgramDir "${Options[@]}" "$PriorityOpt" MANPATH "${Dir}/man" && let ++nConfigured
		
		if [[ $nConfigured -gt 0 ]]; then
			isFlagSet Quiet || echo "Configured ${nConfigured} directories under '${Dir}'"
		else
			ERROR "Directory '${Dir}' had no configurable directories!"
			let ++nErrors
		fi
	done
	return $nErrors
} # ConfigureProgramDir()

