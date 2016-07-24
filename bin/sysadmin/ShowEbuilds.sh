#!/usr/bin/env bash

declare -a EBuilds
declare -i NEBuilds=0
declare -i nErrors=0
for Spec in "$@" ; do
	declare Ebuild
	EBuild="$(equery which "$Spec")"
	res=$?
	if [[ $res != 0 ]]; then
		echo "Failed to find an ebuild for: '${Spec}'"
		let ++nErrors
		continue
	fi
	echo "'${Spec}' => '${EBuild}'"
	EBuilds[NEBuilds++]="$EBuild"
done

if [[ $NEBuilds -gt 0 ]]; then
	less $LESS "${EBuilds[@]}"
fi

exit $nErrors
