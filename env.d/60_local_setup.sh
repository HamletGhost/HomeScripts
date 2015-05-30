#!/bin/bash

function ConfigureProgramDir() {
	# adds one directory to a specified variable, if that directory exists.
	local VarName="$1"
	local Dir="$2"
	[[ -d "$Dir" ]] || return 1
	echo "Adding '${Dir}' to ${VarName}"
	AddToPath "$VarName" "$Dir"
	return 0
} # ConfigureProgramDir()


function ConfigureProgramDirs() {
	# adds the standard POSIX directories to the standard POSIX variables
	# for each of the specified directories
	local Dir
	local -i nErrors=0
	for Dir in "$@"* ; do
		if [[ ! -d "$Dir" ]]; then
			ERROR "${FUNCNAME}: '${Dir}' is not a directory!"
			let ++nErrors
			continue
		fi
	#	echo "Try '${Dir}'"
		
		local -i nConfigured=0
		ConfigureProgramDir PATH "${Dir}/bin" && let ++nConfigured

		if ConfigureProgramDir LD_LIBRARY_PATH "${Dir}/lib64" ; then
			let ++nConfigured
			ConfigureProgramDir PKG_CONFIG_PATH "${Dir}/lib64/pkgconfig" && let ++nConfigured
		elif ConfigureProgramDir LD_LIBRARY_PATH "${Dir}/lib32" ; then
			let ++nConfigured
			ConfigureProgramDir PKG_CONFIG_PATH "${Dir}/lib32/pkgconfig" && let ++nConfigured
		elif ConfigureProgramDir LD_LIBRARY_PATH "${Dir}/lib" ; then
			let ++nConfigured
			ConfigureProgramDir PKG_CONFIG_PATH "${Dir}/lib/pkgconfig" && let ++nConfigured
		fi
		
		ConfigureProgramDir MANPATH "${Dir}/man" && let ++nConfigured
		
		if [[ $nConfigured -gt 0 ]]; then
			echo "Configured ${nConfigured} directories under '${Dir}'"
		else
			ERROR "Directory '${Dir}' had no configurable directories!"
			let ++nErrors
		fi
	done
	return $nErrors
} # ConfigureProgramDir()

