#!/bin/bash

SCRIPTDIR="$(dirname "$0")"

# this very script should be in the repository:
# use it to find where that is
ScriptRealDir="$(readlink -f "SCRIPTDIR")"
AGitPackage="${ScriptRealDir}"
while [[ "$AGitPackage" != '/' ]] && [[ "$AGitPackage" != '.' ]] ; do
	[[ -d "${AGitPackage}/.git" ]] && break
	AGitPackage="$(dirname "$AGitPackage")"
done

[[ "$AGitPackage" == '.' ]] && AGitPackage="$(pwd)"
[[ "$AGitPackage" == '/' ]] && AGitPackage="git/hub/HamletGhost/HomeScripts"

BaseGitRepos="$(dirname "$AGitPackage")"

declare -i nErrors=0
echo "GIT repositories in '${BaseGitRepos}':"
for Dir in "${BaseGitRepos}/"* ; do
	[[ -d "$Dir" ]] || continue
	[[ -d "${Dir}/.git" ]] || continue

	echo " - $(basename "$Dir"):"
	pushd "$Dir" > /dev/null || continue
	git pull || let ++nErrors
	popd > /dev/null
done

exit $nErrors
