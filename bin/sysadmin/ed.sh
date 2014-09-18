#!/bin/bash
#
# Runs the specified emerge command with debug-like options
#

# variables to be imported from make.conf
declare -a VarNames=( CFLAGS CXXFLAGS FEATURES )

# import variables from make.conf
{
	for VarName in "${VarNames[@]}" ; do
		read "$VarName"
	done
} <<< "$(
	source '/etc/portage/make.conf'
	for VarName in "${VarNames[@]}" ; do
		echo "${!VarName}"
	done
)"

export "${VarNames[@]}"
CFLAGS+=" -ggdb"
CXXFLAGS+=" -ggdb"
FEATURES+=" nostrip"

echo "Using:"
for VarName in "${VarNames[@]}" ; do
	echo "${VarName}='${!VarName}'"
done

emerge "$@"

