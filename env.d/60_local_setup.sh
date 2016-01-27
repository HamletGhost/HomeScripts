#!/bin/bash

function ConfigureProgramDir() {
	# adds one directory to a specified variable, if that directory exists.
	OPTIND=1
	local Option
	local PriorityOpt='-a' # append
	while getopts 'ap' Option ; do
		case "$Option" in
			( 'p' | 'a' ) PriorityOpt="-${Option}" ;; # prepend
			( * ) ;;
		esac
	done
	shift $((OPTIND - 1))
	local VarName="$1"
	local Dir="$2"
	[[ -d "$Dir" ]] || return 1
	echo "Adding '${Dir}' to ${VarName}"
	AddToPath "$PriorityOpt" "$VarName" "$Dir"
	return 0
} # ConfigureProgramDir()


function ConfigureProgramDirs() {
	# adds the standard POSIX directories to the standard POSIX variables
	# for each of the specified directories
	OPTIND=1
	local -i DoHelp=0 Priority=0
	local Option
	while getopts 'ph?' Option ; do
		case "$Option" in
			( 'h' | '?' ) DoHelp=1 ;;
			( 'p' ) Priority=1 ;;
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
		    -h , -?
		         show this help message
		
		EOH
		return 0
	fi
	
	local Dir
	local -i nErrors=0
	for Dir in "$@"* ; do
		if [[ ! -d "$Dir" ]]; then
			ERROR "${FUNCNAME}: '${Dir}' is not a directory!"
			let ++nErrors
			continue
		fi
	#	echo "Try '${Dir}'"
	
		local PriorityOpt='-a' # append to the end, low priority
		[[ "$Priority" != 0 ]] && PriorityOpt='-p' # prepend, high priority
			
		local -i nConfigured=0
		ConfigureProgramDir "$PriorityOpt" PATH "${Dir}/bin" && let ++nConfigured

		if ConfigureProgramDir "$PriorityOpt" LD_LIBRARY_PATH "${Dir}/lib64" ; then
			let ++nConfigured
			ConfigureProgramDir "$PriorityOpt" PKG_CONFIG_PATH "${Dir}/lib64/pkgconfig" && let ++nConfigured
		elif ConfigureProgramDir LD_LIBRARY_PATH "${Dir}/lib32" ; then
			let ++nConfigured
			ConfigureProgramDir "$PriorityOpt" PKG_CONFIG_PATH "${Dir}/lib32/pkgconfig" && let ++nConfigured
		elif ConfigureProgramDir LD_LIBRARY_PATH "${Dir}/lib" ; then
			let ++nConfigured
			ConfigureProgramDir "$PriorityOpt" PKG_CONFIG_PATH "${Dir}/lib/pkgconfig" && let ++nConfigured
		fi
		
		ConfigureProgramDir "$PriorityOpt" MANPATH "${Dir}/man" && let ++nConfigured
		
		if [[ $nConfigured -gt 0 ]]; then
			echo "Configured ${nConfigured} directories under '${Dir}'"
		else
			ERROR "Directory '${Dir}' had no configurable directories!"
			let ++nErrors
		fi
	done
	return $nErrors
} # ConfigureProgramDir()

