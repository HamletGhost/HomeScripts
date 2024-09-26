#!/usr/bin/env bash

### program variables
: ${SED:="sed"}
#####################

PROGRAMNAME=`basename $0`
CWD=`pwd`

###  library and specfifc functions

function isSet() {
	VARNAME="$1"
	[ -n "${!VARNAME}" ] && [ "${!VARNAME}" != 0 ]
}

function isDebug() {
	isSet DEBUG
}

function DBG() {
	isDebug && echo $*
}

function DBGEXEC() {
	if isDebug; then
		echo $@
	else
		$@
		return $?
	fi
}

function PRINT() {
	VLEVEL=$1
	shift
	[ -n "VERBOSE" -a "$VLEVEL" -le "$VERBOSE" ] && echo $*
}

function ERROR() {
	echo $* >&2
}

function FATAL() {
	CODE=$1
	shift
	ERROR $*
	exit $CODE
}

function DUMP_VAR {
	for VARNAME in $* ; do
		ERROR "$VARNAME = ${!VARNAME}"
	done
}


function help {
	cat <<EOF

Renames files.

Usage:  $PROGRAMNAME  [options] destmask files

All specified files are renamed according to destmask. This is a sed "s" command.
For example, to rename all g* programs in /usr/bin in g*.old , run:

$PROGRAMNAME  '@/g\(.*\)@/g\1.old@' /usr/bin/g*

Have you done it? were you root? ok, the system is messed up. But, you can return back with:

$PROGRAMNAME  '@/g\(.*\).old@/g\1@' /usr/bin/g*.old

Seriously, use this with care and use ALWAYS -n the first time to check what you are going to do.


Options:
-n , --fake , --pretend
	just prints what it would do

EOF
}

function options_parser {
	NPARAMS=$#
	NFINALPARAMS=0
	DOUBLEDASH=0
	for (( i = 1 ; $i <= $NPARAMS ; ++i )); do
		SKIP=1
		PARAM=${!i}
		case "$PARAM" in
			--help | -h )
				HELP=1
				;;
			--debug | -d )
				DEBUG=1
				;;
			--pretend | --fake | -n )
				PRETEND=1
				;;
			-- )
				DOUBLEDASH=$i
				break
				;;
			* )
				SKIP=0
				;;
		esac
		if [ "$SKIP" == 0 ]; then
			NFINALPARAMS=${#PARAMS[*]}
			PARAMS[$NFINALPARAMS]="$PARAM"
		fi
	done
	NFINALPARAMS=${#PARAMS[*]}
	isDebug && echo "Parameters ($NFINALPARAMS) list:" "${PARAMS[@]}"
}


function dump_all_vars {
	DUMP_VAR PROGRAMNAME PARAMS NFINALPARAMS SED VERBOSE DEBUG HELP PRETEND DOUBLEDASH
}


### script starts here ########################################################
options_parser "$@"

if isSet HELP ; then
	help
	exit 0
fi

if [[ "$NFINALPARAMS" -lt 2 ]] ; then
	help
	exit 1
fi

COMMAND="${PARAMS[0]}"

for (( iParam = 1 ; iParam < $NFINALPARAMS ; ++iParam )); do
	FILENAMES=${PARAMS[$iParam]}
	for FILENAME in $FILENAMES ; do
		if [ ! -e "$FILENAME" ]; then
			ERROR "Can't find '$FILENAME'."
			continue
		fi
		NEWNAME=`echo "$FILENAME" | sed -e "s$COMMAND"`
		
		if [ "$NEWNAME" == "$FILENAME" ]; then
			echo "'$FILENAME' keeps its name."
			continue
		fi
		
		if isSet PRETEND ; then
			echo "'$FILENAME' -> '$NEWNAME'"
		else
			mv -v "$FILENAME" "$NEWNAME"
		fi
	done
done

isSet PRETEND && echo ">>> No change was actually made. <<<"
