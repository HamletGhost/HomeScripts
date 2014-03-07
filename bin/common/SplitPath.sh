#!/bin/bash

: ${SEP:=":"}

for VarName in "$@" ; do
	case "$VarName" in
		( '@lib' )
			VarName='LD_LIBRARY_PATH'
			;;
		( '@bin' )
			VarName='PATH'
			;;
	esac
#	echo "${VarName}"
	tr "$SEP" "\n" <<< "${!VarName}"
done

