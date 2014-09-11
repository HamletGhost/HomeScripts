#!/bin/sh

SCRIPTNAME="$(basename "$0")"

: ${GentooMakeConf:="/etc/make.conf"}

function isFlagSet() {
	local VarName="$1"
	[[ -n "${!VarName//0}" ]]
}

function STDERR() {
	echo "$*" >&2
}

function ERROR() {
	STDERR "ERROR: $*"
}

function FATAL() {
	local Code="$1"
	shift
	STDERR "FATAL ERROR (${Code}): $*"
	exit "$Code"
}

function ClearTempFiles() {
	[[ -n "$TempFile" ]] && rm -f "$TempFile"
}

function Clean() {
	ClearTempFiles
}


function help() {
	cat <<EOH
Prints the packages used by each of the specified Gentoo use flags.

Syntax:  ${SCRIPTNAME} [options] [Flag] [Flag] [...]

Options:
-z , --unusedonly
	only prints flags not used by ant package
-u , --usedonly
	only prints flags used by at least one package
-n , --nopackages
	don't print the names of the packages using each flag, only the number
EOH
}


# get ready to clean our tracks any time:
trap Clean EXIT


declare -a Flags
declare -i NFlags=0
declare -i PrintMin=-1
declare -i PrintMax=-1
# parse command line and get flags from there
for (( iParam = 1 ; iParam <= $# ; ++iParam )); do
	Param="${!iParam}"
	case "$Param" in
		( -* )
			if ! isFlagSet NoMoreOptions ; then
				KnownOption=1
				case "$Param" in
					( '--help' | '-h' | '-?' )
						DoHelp=1
						;;
					( '-z' | '--unusedonly' )
						PrintMin=0
						PrintMax=1
						;;
					( '-u' | '--usedonly' )
						PrintMin=1
						PrintMax=-1
						;;
					( '-n' | '--nopackages' )
						NoPackages=1
						;;
					( '--' )
						NoMoreOptions=1
						;;
					( * )
						KnownOption=0
						;;
				esac
				isFlagSet KnownOption && continue
			fi
			# don't break!
		( * )
			Flags[NFlags++]="$Param"
			;;
	esac
done

if isFlagSet DoHelp ; then
	help
	exit
fi

if [[ "$NFlags" == 0 ]]; then
	source "$GentooMakeConf"
	Flags=( $USE )
	NFlags=${#Flags[@]}
fi

TempFile="$(mktemp "${SCRIPTNAME%.sh}-tmp.XXXXXX")"

declare -i iFlag=0
declare -i FlagsFieldWidth="${#NFlags}"
echo "Checking for ${NFlags} use flags:"
for Flag in "${Flags[@]}" ; do
	let ++iFlag
	equery hasuse "$Flag" 1> "$TempFile" 2> /dev/null
	res=$?
	if [[ $res == 1 ]]; then
		echo "Use flag query failed (code: $res)." >&2
		break
	fi
	NUsingPackages="$(wc -l "$TempFile" | awk '{ print $1 ; }' 2> /dev/null)"
	FlagIntro="[$(printf "%0${FlagsFieldWidth}d" "$iFlag" )/${NFlags}] flag '${Flag}'"
	if [[ -z "$NUsingPackages" ]]; then
		echo "${FlagIntro} could not be checked!"
	else
		[[ $PrintMin -ge 0 ]] && [[ $NUsingPackages -lt $PrintMin ]] && continue
		[[ $PrintMax -ge 0 ]] && [[ $NUsingPackages -ge $PrintMax ]] && continue

		if [[ "$NUsingPackages" == 0 ]]; then
			echo "${FlagIntro} is not used by any package."
		else
			echo "${FlagIntro} is used by ${NUsingPackages} packages"
			isFlagSet NoPackages || cat -n "$TempFile"
		fi
	fi
done

ClearTempFiles

