#!/bin/sh
#
# Obtains a Kerberos ticket.
#

################################################################################
# sourcing check:
# define a isScriptSourced() function returning whether the script is sourced;
# if a function of that name is already defined, we assume it has the same
# functionality and we use it.
# If we define our function, it will self-destruct after the first use if it
# finds out it's being sourced, so that the calling environment is not polluted.
declare -f isScriptSourced >& /dev/null || function isScriptSourced() {
	# echo "BASH_SOURCE='${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]}' \$0='${0}'"
	if [[ "${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]}" != "$0" ]]; then
		unset -f "${FUNCNAME[0]}" # self-destruction
		return 0 # sourced; $0 = -bash or something
	else
		return 1 # subshell
	fi
} # isScriptSourced()


################################################################################
###  Source mode
################################################################################
if isScriptSourced ; then
	
	function GetTicket_LocalExecute() {
		local CommandsStream="$(mktemp --tmpdir 'GetTicket_commands.XXXXXXXXX')"
		
		#
		# runs this script in a subshell and in a special mode
		# where standard output contains commands to be executed, and executes them.
		# The return code of the script is propagate to the subshell, then to
		# eval, that being the last command determines the exit code of the sourced
		# script.
		#
		( "${BASH_SOURCE[0]}" --commands="$CommandsStream" "$@" )
		
		source "$CommandsStream"
		rm -f "$CommandsStream"
		
		unset GetTicket_LocalExecute # self-destruction
		return $?
	}
	
	GetTicket_LocalExecute
	return $?
fi


################################################################################
###  Script mode
################################################################################
SCRIPTNAME="$(basename "$0")"
SCRIPTDIR="$(dirname "$0")"
SCRIPTVERSION="v. 2.0"

###
### scripts defaults
###
: ${DEFAULTUSER='petrillo'}
: ${DEFAULTREALM='FNAL.GOV'}

[[ "${#DEFAULTKRB5OPTS[*]}" == 0 ]] && DEFAULTKRB5OPTS=( "-f" )

: ${DoRenewTicket:=1}
: ${DoGetNewTicket:=1}

: ${KRB5LIFETIME:="26h"}
: ${KRB5RENEWTIME:="7d"}
: ${NAT:="0"}

: ${kinit:="kinit"}
: ${mkdir:="mkdir -p"}



function isFlagSet() {
	local VarName="$1"
	[[ -n "${!VarName//0}" ]]
} # isFlagSet()

function isFlagUnset() {
	local VarName="$1"
	[[ -z "${!VarName//0}" ]]
} # isFlagUnset()


function STDERR() { echo "$*" >&2 ; }
function ERROR() { STDERR "ERROR: $*" ; }

function FATAL() {
	local Code=$1
	shift
	STDERR "FATAL (${Code}): $*"
	exit $Code
} # FATAL()

function isDebugging() {
	local -i Level="${1:-1}"
	[[ -n "$DEBUG" ]] && [[ "$DEBUG" -ge "$Level" ]]
} # isDebugging()

function DBGN() {
	local -i Level="$1"
	isDebugging "$Level" || return 0
	shift
	STDERR "DBG[${Level}]| $*"
} # DBGN()
function DBG() { DBGN 1 "$*" ; }

function MSG() { echo "$*" ; }

function ExecCommand() {
	DBG "$@"
	"$@"
} # ExecCommand()

function FlagValue() {
	local VarName="$1"
	isFlagSet "$VarName" && echo 1 || echo 0
} # FlagValue()

function FlipFlagValue() {
	local VarName="$1"
	isFlagSet "$VarName" && echo 0 || echo 1
} # FlipFlagValue()


function help() {
	cat <<-EOH
	Gets or renews a Kerberos5 ticket.
	
	Usage:  $SCRIPTNAME [options] [Realm]
	
	The default realm is '${DEFAULTREALM}'
	
	Options:
	--user=KRB5USER ${KRB5USER:+"['${KRB5USER}']"}
	    the Kerberos user to get ticket for
	--instance=KRB5INSTANCE ${KRB5INSTANCE:+"['${KRB5INSTANCE}']"}
	    the instance (usually nothing at all)
	--root
	    a shortcut for '--instance=root'
	--fulluser=KRB5FULLUSER
	    override the full Kerberos user specification (user/instance@DOMAIN)
	--norenew
	    do not try to renew the Kerberos ticket, always obtain a new one
	--onlyrenew
	    do not try to get a new Kerberos ticket, always renew a currrent one
	    (failing if it's not possible)
	--lifetime=LIFETIME ['${KRB5LIFETIME}']
	    overrides the lifetime of the ticket: after the ticket lifetime is
	    expired, it has to be renewed
	--renewtime=RENEWTIME ['${KRB5RENEWTIME}']
	    overrides the renewable time of the ticket: after the ticket renewable
	    time is out, a new ticket must be obtained since the current one can't
	    be renewed any more
	--nat
	    tells Kerberos we are behind a NAT
	
	EOH
} # help()


function RemoveKerberosOption() {
	local Key="$1"
	local -i NValues="$#"
	local -i iOption=0
	while [[ $iOption -lt "${#KerberosOptions[@]}" ]]; do
		local Option="${KerberosOptions[iOption]}"
		if [[ "$Option" == "$Key" ]]; then
			# remove NValue keys
			local nKeys
			for (( nKeys = 0 ; nKeys < $NValue ; ++nKeys )); do
				unset KerberosOptions[iOption]
			done
			break
		fi
		let ++iOption
	done
} # RemoveKerberosOption()

function AddKerberosOption() {
	RemoveKerberosOption "$@"
	KerberosOptions=( "${KerberosOptions[@]}" "$@" )
} # AddKerberosOption()


function AddAction() { Actions=( "${Actions[@]}" "$@" ) ; }

function AddCommand() {
	[[ -w "$CommandsStream" ]] || return
	echo "$@" >> "$CommandsStream"
} # AddCommand()


################################################################################
function RenewTicket() {
	
	local Principal="$1"
	local KRB5CCName="$2"
	local -i GotTicket=0
	
	ExecCommand $kinit ${KRB5CCName:+ -c "$KRB5CCName"} -R "$Principal"
	local res=$?
	if [[ $res == 0 ]]; then
		MSG "An existing ticket for user '${KRB5USER}'${KRB5INSTANCE:+" (instance '${KRB5INSTANCE}')"} on realm '${KRB5REALM}' was successfully renewed."
		GotTicket=1
	fi
	isFlagSet GotTicket
} # RenewTicket()


function GetTicket() {
	
	local -i GotTicket=0
	
	# determine the full user string (user[/instance]@DOMAIN)
	: ${KRB5FULLUSER:="${KRB5USER}${KRB5INSTANCE:+"/${KRB5INSTANCE}"}@${KRB5REALM}"}
	
	#
	# The system could have set KRB5CCNAME variable and there could be a valid
	# ticket there; if so, we try to use it, unless we really want a new one:
	#
	if isFlagSet DoRenewTicket ; then
		RenewTicket "$KRB5FULLUSER" && GotTicket=1
	fi
	
	# we might need in some cases to have the ticket in a shared location
	# (that the default location typically is not).
	# In that case, we'll have to resurrect code similar to the following:
# 	: ${KRB5BASECCDIR:="${HOME}/tmp/krb5"}
# 	KRB5CCNAME="${KRB5BASECCDIR}/${KRB5USER}/${KRB5INSTANCE:-"$KRB5USER"}"
# 	$mkdir "$(dirname "$KRB5CCNAME")"
# 	AddCommand "export KRB5CCNAME='${KRB5CCNAME}'"
	
	if isFlagUnset GotTicket && isFlagSet DoGetNewTicket ; then
		
		if [[ "$KRB5INSTANCE" == "root" ]]; then  # non-forwardable
			RemoveKerberosOption '-f' # get rid of the forward options...
			AddKerberosOption '-F' # ... and add just one non-forwardable option
		fi
		[[ -n "$KRB5LIFETIME" ]] && AddKerberosOption "-l${KRB5LIFETIME}"
		[[ -n "$KRB5RENEWTIME" ]] && AddKerberosOption "-r${KRB5RENEWTIME}"
		[[ -n "$KRB5CCNAME" ]] && AddKerberosOption "-c" "$KRB5CCNAME"
		isFlagSet NAT && AddKerberosOption '-n'
		
		MSG "Getting a new Kerberos5 ticket: prepare your '${KRB5REALM}' password."
		ExecCommand $kinit "${KerberosOptions[@]}" "$KRB5FULLUSER"
		res=$?
		DBG "Exit code: $res"
		[[ $res == 0 ]] && GotTicket=1
	fi
	
	isFlagSet GotTicket || FATAL $res "Couldn't get a new Kerberos5 ticket. Hope there is a valid, existing one."
	
	# if there is OpenAFS loaded, try to authenticate with aklog:
	[[ -d '/proc/fs/openafs' ]] && which 'aklog' >& /dev/null && aklog
	
} # GetTicket()

################################################################################
###
### parameter parsing
###

declare -a KerberosOptions=( "${DEFAULTKRB5OPTS[@]}" )
declare -a Actions
declare -i NoMoreOptions=0
declare -a Arguments
declare -i NArguments=0
for (( iParam = 1 ; iParam <= $# ; ++iParam )); do
	Param="${!iParam}"
	if [[ "${Param:0:1}" == '-' ]] && isFlagUnset NoMoreOptions ; then
		case "$Param" in
			### settings ###
			( '--user='* )             KRB5USER="${Param#--*=}" ;;
			( '--instance='* )         KRB5INSTANCE="${Param#--*=}" ;;
			( '--realm='* )            KRB5REALM="${Param#--*=}" ;;
			( '--root' )               KRB5INSTANCE='root' ;;
			( '--fulluser='* )         KRB5FULLUSER="${Param#--*=}" ;;
			( '--norenew' )            NoRenew=1 ;;
			( '--onlyrenew' )          RenewOnly=1 ;;
			( '--nat' )                NAT=1 ;;
			
			( '--lifetime='* )         KRB5LIFETIME="${Param#--*=}" ;;
			( '--renewtime='* )        KRB5RENEWTIME="${Param#--*=}" ;;
			
			### operating modes ###
			( '--commands='* )         CommandsStream="${Param#--*=}" ;;
			
			### common options ###
			( '--debug' )              DEBUG=1 ;;
			( '--debug='* )            DEBUG="${Param#--*=}" ;;
			( '--version' | '-V' )     AddAction 'PrintVersion' ;;
			( '--help' | '-h' | '-?' ) AddAction 'PrintHelp' ;;
		esac
	else
		[[ $NArguments -gt 2 ]] && FATAL 1 "${SCRIPTNAME} suffers only ${NArguments} arguments! -- '${Param}'"
		
		Arguments[NArguments++]="$Param"
	fi
done

# set default actions
if [[ "${#Actions[@]}" == 0 ]]; then
	AddAction 'GetTicket'
fi

# process the parameters
declare -i DoRenewTicket=$(FlipFlagValue NoRenew)
declare -i DoGetNewTicket=$(FlipFlagValue OnlyRenew)

KRB5REALM="${Arguments[0]:-${KRB5REALM:-${DEFAULTREALM}}}"
: ${KRB5USER:="${DEFAULTUSER}"}

[[ -n "$KRB5REALM" ]] || FATAL 1 "No Kerberos realm specified!"

if [[ -n "$CommandsStream" ]]; then
	if [[ ! -w "$CommandsStream" ]]; then
		touch "$CommandsStream" || FATAL 2 "The commands stream '${CommandsStream}' can't be written"
	fi
	DBG "Adding commands to: '${CommandsStream}'"
fi

###
### Performs the actions
###
declare ExitCode=0
for Action in "${Actions[@]}" ; do
	case "$Action" in
		( 'PrintVersion' )
			echo "${SCRIPTNAME} ${SCRIPTVERSION}"
			;;
		( 'PrintHelp' )
			help
			;;
		( 'GetTicket' )
			GetTicket
			;;
		( 'Exit' )
			break
			;;
		( * )
			FATAL 1 "Internal error: action '${Action}' not supported!"
	esac
	
done

exit "$ExitCode"

################################################################################
