#!/bin/sh

SCRIPTNAME="$(basename "$0")"

: ${MISSINGSOURCES:="0"}
: ${UNUSEDSOURCES:="1"}
: ${DELETETEMP:="1"}

UsedFiles="${TMP:-"${TEMP:-"/var/tmp"}"}/${SCRIPTNAME/./_}-usedfiles.list"
StoredFiles="${TMP:-"${TEMP:-"/var/tmp"}"}/${SCRIPTNAME/./_}-storedfiles.list"


echo "Getting the list of needed source files (note any fetch-restricted file!)..."
emerge -efp world | grep -v -e '^ ' -v -e '\!' | tr ' ' '\n' | grep '://' | sed -e 's@.*/@@g' | sort -u > "$UsedFiles"

echo "Getting stored files..."
find /usr/portage/distfiles -maxdepth 1 -type f | sed -e 's@.*/@@g' | sort -u > "$StoredFiles"


if [[ -n "${UNUSEDSOURCES//0}" ]]; then
	echo "Unneeded source files:"
	comm -2 -3 "$StoredFiles" "$UsedFiles"
fi

if [[ -n "${MISSINGSOURCES//0}" ]]; then
	echo "Missing source files:"
	comm -1 -3 "$StoredFiles" "$UsedFiles"
fi

if [[ -n "${DELETETEMP//0}" ]]; then
	rm -f "$StoredFiles" "$UsedFiles"
else
       echo "Temporary files not erases: '${StoredFiles}' '${UsedFiles}'"
fi
