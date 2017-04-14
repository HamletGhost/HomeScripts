#!/bin/bash

SCRIPTDIR="$(dirname "$0")"

: ${MODE:='pull'}

declare -i nParams=0
declare -a Params
declare -i NoMoreOptions=0
declare Mode="pull"
for (( iParam = 1 ; iParam <= $# ; ++iParam )); do
	Param="${!iParam}"
	if [[ "${Param:0:1}" == '-' ]] && [[ -z "${NoMoreOptions//0}" ]]; then
		case "$Param" in
			( '--push' | '--pull' | '--status' | '--diff' | '--commit' ) MODE="${Param#--}" ;;
			( '-' | '--' ) NoMoreOptions=1 ;;
			( * )
				Params[nParams++]="$Param"
				;;
		esac
	else
		Params[nParams++]="$Param"
	fi
done


case "$MODE" in
	( 'push' ) GITCOMMAND='push' ;;
	( 'pull' ) GITCOMMAND='pull' ;;
	( 'diff' ) GITCOMMAND='diff' ;;
	( 'commit' ) GITCOMMAND='commit -a' ;;
	( 'status' ) GITCOMMAND='status' ;;
	( * )
		echo "Invalid mode - '${MODE}'"
		exit 1
		;;
esac


# this very script should be in the repository:
# use it to find where that is
ScriptRealDir="$(full_path -f "$SCRIPTDIR")"
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
	git ${GITCOMMAND} || let ++nErrors
	popd > /dev/null
done

exit $nErrors
