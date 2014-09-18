#!/bin/bash

SCRIPTNAME="$(basename "$0")"

: ${TMP:="${TEMP:-"/var/tmp"}"}

: ${NeededListFile="${TMP}/${SCRIPTNAME/./_}-needed.list"}
: ${InstalledListFile="${TMP}/${SCRIPTNAME/./_}-installed.list"}
: ${CandidatesListFile:="${TMP}/${SCRIPTNAME/./_}-candidate.list"}

echo "Extracting needed packages..."
emerge --emptytree --pretend world | grep '^\[ebuild' | sed -e 's/\[[^]]*] \([^ ]\+\).*/\1/' -e 's/-r[^-]*$//' -e 's/-[^- ]*$//' | sort -u > "$NeededListFile"

echo "Extracting installed packages..."
equery --no-pipe list | grep '^\[' | sed -e 's/\[.*\] //' -e 's/-r[^- ]* (/ (/' -e 's/-[^- ]* (/ (/' | sort -u > "$InstalledListFile"
grep '(0)' "$InstalledListFile" | sed -e 's/ \+(0)//' > "$CandidatesListFile"

echo "Checking for unneeded packages:"
for package in $(comm -2 -3 "$CandidatesListFile" "$NeededListFile") ; do
	Depends=$(equery depends "$package" | wc -l ) 
	[[ "$Depends" == 0 ]] && echo "$package"
done

echo "Missing packages:"
comm -1 -3 <( cat "$InstalledListFile" | awk '{ print $1 ; }' ) "$NeededListFile"

# rm -f "$NeededListFile" "$InstalledListFile" "$CandidatesListFile"

