#!/bin/sh

SCRIPTNAME="$(basename "$0")"
SCRIPTDIR="$(dirname "$0")"

# if an instance is specified (r.g. user/root@REALM),,
# the DB file of Kerberos5 tickets is kept in a special file in KRB5BASECCDIR,
# which by default is in the unser's home directory.
# If the following is set to true, that will happen even if no instance is specified;
# otherwise the default location is used, which is chosen by Kerberos
# and it's usuallt in the system temporary directory.
# In case a special location is used, it should be set up in .bashrc .
USEDEFAULTIFNOINSTANCE=1

: ${DoRenewTicket:=1}
: ${DoGetNewTicket:=1}

function isHelpReq() {
	[[ "$1" == "-h" ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-?" ]]
}

if ! isHelpReq "$1" ; then
	if [[ -z "$1" ]]; then
		: ${KRB5REALM:="FNAL.GOV"}
	else
		KRB5REALM="$1"
	fi
	shift
fi

if [[ -n "$1" ]] && ! isHelpReq "$1" ; then
	if [[ "${1:0:1}" == "/" ]]; then
		KRB5INSTANCE="${1/\/}"
	elif [[ "${1/\/}" != "$1" ]]; then
		KRB5USER="${1/\/*}"
		KRB5INSTANCE="${1/*\/}"
	else
		KRB5USER="$1"
	fi
	shift
fi

: ${KRB5USER:="petrillo"}

: ${KRB5LIFETIME:="26h"}
: ${KRB5RENEWTIME:="7d"}
: ${KRB5OPTS:="-f"}
: ${NAT:="0"}

: ${kinit:="kinit"}
: ${mkdir:="mkdir -p"}

: ${KRB5BASECCDIR:="${HOME}/tmp/krb5"}

function isFlagSet() {
	local VARNAME="$1"
	[[ -n "${!VARNAME}" ]] && [[ "${!VARNAME}" != 0 ]]
}

function ERROR() {
	echo "$*" >&2
}

function FATAL() {
	local code=$1
	shift
	ERROR "$SCRIPTNAME - Fatal error: $*"
	exit $code
}

function isDebugging() {
	isFlagSet DEBUG
}

function DBG() {
	isDebugging && ERROR "$*"
}


function isSourced() {
	# tries to detect if this is sourced
	[[ "$0" == "$SHELL" ]]
}


function help() {
	cat <<EOH
Gets or renews a Kerberos5 ticket.

Usage:  $SCRIPTNAME [Realm] [Instance] [options]

Instance can be in the form [User][/Instance], where either User or Instance
is mandadory, the other is optional; note that the slash is also mandatory if an
instance is specified.

Example:

$SCRIPTNAME "" '/root'

will require for the default realm ('${KRB5REALM}'), since it's specified empty,
a ticket for the current user ('${KRB5USER}') with instance 'root'.

Variables:
KRB5USER ('$KRB5USER')
	the Kerberos user to get ticket for
KRB5INSTANCE ('$KRB5INSTANCE')
	the instance (usually nothing at all)

EOH
	[[ -n "$1" ]] && exit $1
}

isHelpReq "$1" && help 0

isFlagSet ROOT && [[ -z "$KRB5INSTANCE" ]] && KRB5INSTANCE="root"

if [[ -z "$KRB5FULLUSER" ]]; then
	if [[ -n "$KRB5INSTANCE" ]]; then
		KRB5FULLUSER="${KRB5USER}/${KRB5INSTANCE}@${KRB5REALM}"
	else
		KRB5FULLUSER="${KRB5USER}@${KRB5REALM}"
	fi
fi
if [[ -z "$KRB5INSTANCE" ]] && isFlagSet USEDEFAULTIFNOINSTANCE ; then
	if [[ -n "$KRB5CCNAME" ]]; then
		unset KRB5CCNAME
		echo "unset KRB5CCNAME"
	fi
else
	KRB5CCNAME="${KRB5BASECCDIR}/${KRB5USER}/${KRB5INSTANCE:-"$KRB5USER"}"
	$mkdir "$(dirname "$KRB5CCNAME")"
	if isSourced ; then
		export KRB5CCNAME # probably useless
	else
		ERROR "Remember to change the KRB5CCNAME as follows:"
	fi
	echo "export KRB5CCNAME=\"${KRB5CCNAME}\""
fi

declare -i GotTicket=0

# first try to renew an existing one
if isFlagSet DoRenewTicket ; then
	DBG $kinit ${KRB5CCNAME:+ -c "$KRB5CCNAME"} -R "$KRB5FULLUSER"
	$kinit ${KRB5CCNAME:+ -c "$KRB5CCNAME"} -R "$KRB5FULLUSER" >& /dev/null
	res=$?
	if [[ $res == 0 ]]; then
		echo "An existing ticket for user '${KRB5USER}'" "$([[ -n "$KRB5INSTANCE" ]] && echo " (instance '${KRB5INSTANCE}')" )"" on realm '${KRB5REALM}' was successfully renewed."
		GotTicket=1
	fi
fi
if isFlagSet DoGetNewTicket && ! isFlagSet GotTicket ; then
	if [[ "$KRB5INSTANCE" == "root" ]]; then  # non-forwardable
		KRB5OPTS="${KRB5OPTS/-f}" # get rid of the forward options...
		KRB5OPTS="${KRB5OPTS/-F} -F" # ... and add just one non-forwardable option
	fi
	KRB5OPTS="${KRB5OPTS}${KRB5LIFETIME:+ -l${KRB5LIFETIME}}${KRB5RENEWTIME:+ -r${KRB5RENEWTIME}}${KRB5CCNAME:+ -c ${KRB5CCNAME}}"
	isFlagSet NAT && KRB5OPTS="${KRB5OPTS} -n"
	echo "Getting a new Kerberos5 ticket: prepare your '${KRB5REALM}' password."
	DBG $kinit $KRB5OPTS "$KRB5FULLUSER"
	$kinit $KRB5OPTS "$KRB5FULLUSER"
	res=$?
	DBG "Exit code: $res"
	[[ $res == 0 ]] && GotTicket=1
fi

isFlagSet GotTicket || FATAL $res "Couldn't get a new Kerberos5 ticket. Hope there is a valid, existing one."

# if there is OpenAFS loaded, try to authenticate with aklog:
if [[ -d '/proc/fs/openafs' ]]; then
	aklog
fi

