#!/usr/bin/env bash

function DoConfigure() {
	local -ra Dirs=( "${HOME}/local" )
	local Dir
	local -i nErrors=0
	for Dir in "${Dirs[@]}" ; do
		[[ -d "$Dir" ]] || continue
		ConfigureProgramDirs "$Dir" > /dev/null || let ++nErrors
	done
	unset DoConfigure
	return $nErrors
} # DoConfigure()

DoConfigure

