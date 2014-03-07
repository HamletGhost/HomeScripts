#!/bin/sh
#

### program variables
: ${TIMETYPE:="T"}
: ${FIND:="find"}
: ${SORT:="sort"}
: ${CUT:="cut"}
: ${PRINTF:=""}
: ${FINDOPTIONS:=""}
: ${FINDACTIONS:=""}
: ${FINDTESTS:=""}
#####################

### program variable check
[ "$TIMETYPE" != "T" ] && [ "$TIMETYPE" != "C" ] && [ "$TIMETYPE" != "A" ] && TIMETYPE="T"

PROGRAMNAME=`basename $0`
CWD=`pwd`
TIMEKEY="%${TIMETYPE}Y%${TIMETYPE}m%${TIMETYPE}d%${TIMETYPE}H%${TIMETYPE}M%${TIMETYPE}S"


###  library and specfifc functions

function isDebug() {
	[ -n "$DEBUG" -a "$DEBUG" != 0 ]
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

Lists files in last modification order.

Usage:  $PROGRAMNAME  [options] [basedir] [-- find options]

Serach starts from basedir (current directory by default).

Options following a double dash ("--") will be passed directly to the finder program ($FIND).
Local options:
-n, --pretend
	shows the command that would be used, doesn't run it
-r, --reverse
	reverse the order
-d, --nodir, --nodirectories
	add "-not -type d" option to skip printing directories
-l, --nolinks
	add "-not -type l" option to skip printing symbolic links

Variables: to have a custom printout of listing, you can redefine PRINTF environment variable, e.g.

PRINTF="%p\n" $PROGRAMNAME

will print only the (complete) name of files. If you want to change completely the printing,
you can pass your find commands to the script in FINDACTIONS variable; in that case, PRINTF variable will
be cleared and your new action must end the line outputting a carriage return. E.g.

FINDACTIONS="-print" $PROGRAMNAME

has the same effect as above. The only mandatory constraint is to have exactly one line for each file
(don't put more than one carriage return, nor cut it away at all).
By default, if neither FINDACTIONS nor PRINTF are specified, the former is set to "-ls".

There are tree variables which can be passed to the finder to customize its behaviour:
FINDOPTIONS for options: they are placed just after directories in finder command;
FINDTESTS for tests: they are placed between the options and the default "printf" action;
FINDACTIONS for actions: they are placed at the very end of the finder command;
Run:

FINDOPTIONS=options FINDTESTS=tests FINDACTIONS=actions $PROGRAMNAME --pretend

to see where options are placed in finder command.
Another way to specify options is to specify them after a double dash:

FINDOPTIONS="-follow -xdev" $PROGRAMNAME
FINDOPTIONS="-follow" $PROGRAMNAME -- -xdev

have the same effect.

The sorting follow modification time ("T"); changing variable TIMETYPE to "C" will use
status change time instead, while "A" will use last access time. No other value is allowed.

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
			--pretend | -n )
				PRETEND=1
				;;
			--reverse | -r )
				REVERSE=1
				;;
			--nodirectories | --nodir | -d )
				NODIRECTORIES=1
				;;
			--nolinks | -l )
				NOLINKS=1
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
	isDebug && echo "Parameters list:" "${PARAMS[@]}"
}


function dump_all_vars {
	DUMP_VAR PROGRAMNAME PARAMS NFINALPARAMS SORT CUT FIND VERBOSE DEBUG HELP REVERSE PRETEND DOUBLEDASH FINDOPTIONS SORTOPTIONS
}


### script starts here ########################################################
options_parser "$@"

# options implementation
[ -n "$NODIRECTORIES" ] && FINDOPTIONS="$FINDOPTIONS -not -type d"
[ -n "$NOLINKS" ] && FINDOPTIONS="$FINDOPTIONS -not -type l"
if [ "$DOUBLEDASH" != 0 ]; then
	shift $DOUBLEDASH
	FINDOPTIONS="$FINDOPTIONS $@"
fi

SORTOPTIONS=
[ -n "$REVERSE" ] && SORTOPTIONS="-r"

[ -z "$FINDACTIONS" ] && [ -z "$PRINTF" ] && FINDACTIONS="-ls"

if [ -n "$HELP" ]; then
	help
	exit 0
fi

[ -n "$DEBUG" -a "$DEBUG" != 0 ] && dump_all_vars


# the work:
if [ -n "$PRETEND" ] || isDebug ; then
	echo "$FIND" "${PARAMS[@]}" $FINDOPTIONS $FINDTESTS -printf "$TIMEKEY$PRINTF" $FINDACTIONS
else
	ERROR -en "Searching...\r"
	"$FIND" "${PARAMS[@]}" $FINDOPTIONS $FINDTESTS -printf "$TIMEKEY$PRINTF" $FINDACTIONS | "$SORT" $SORTOPTIONS | "$CUT" --bytes=15-
fi
