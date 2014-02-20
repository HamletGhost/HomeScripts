#!/bin/sh

: ${pstoeps:="ps2epsi"}

function isFlagSet() {
	local VarName="$1"
	[[ -n "${!VarName//0}" ]]
}

BoundingBoxKey="%%BoundingBox"
isFlagSet HiRes && BoundingBoxKey="%%HiResBoundingBox"

for SrcFile in "$@" ; do
	[[ -r "$SrcFile" ]] || continue
	EpsFile="${SrcFile}.eps"
	[[ ! -r "$EpsFile" ]]
	EpsExists=$?
	if isFlagSet EpsExists ; then
		echo "Warning: using existing EPS file to detect the following bounding box" >&2
	else
		$pstoeps "$SrcFile" "$EpsFile"
		if [[ $? != 0 ]] || [[ ! -r "$EpsFile" ]]; then
			echo "Failed to create '${EpsFile}'" >&2
			continue
		fi
	fi
		
	echo "${SrcFile}: $(cat "$EpsFile" | tr '\r' '\n' | grep "${BoundingBoxKey}" | sed -e "s/${BoundingBoxKey}//" )"
	isFlagSet EpsExists || rm -f "$EpsFile"
done
