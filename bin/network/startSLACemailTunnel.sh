#!/usr/bin/env bash
#
# Attempts to establish a tunnel to DestServer:DestPort via SSH through LocalPort.
#
#

Server='iris'
declare -ir LocalPorts=( 10993 10587 )
declare -r  DestServers=( 'outlook.office365.com' )
declare -ir DestPorts=( 993 587 )

declare -r BrightGreen="\e[32;1m"
declare -r BrightRed="\e[31;1m"
declare -r Cyan="\e[36m"
declare -r Reset="\e[0m"
declare -r FailureColor="$BrightRed"
declare -r SuccessColor="$BrightGreen"
declare -r InfoColor="$Cyan"
declare -r ResetColor="$Reset"

################################################################################
function ColorPrint() {
  declare -r ColorCode="$1"
  shift
  echo -e "${ColorCode}${*}${ResetColor}"
} # ColorPrint()
function Success() { ColorPrint "$SuccessColor" "$*" ; }
function Failure() { ColorPrint "$FailureColor" "$*" ; }
function Info() { ColorPrint "$InfoColor" "$*" ; }

function ListPort() {
  local -i Port="$1"
  shift
  local -a Options=( "$@" )
  ss "${Options[@]}" state listening "sport = :${Port}"
} # ListPort()

function isPortOpen() {
  local -i Port="$1"
  local -i NOpen="$( ListPort "$Port" --no-header | wc -l )"
  [[ $NOpen == 1 ]]
} # isPortOpen()


################################################################################
ServerScriptPath="$(which "$Server" 2> /dev/null)"
if [[ ! -x "$ServerScriptPath" ]]; then
  Failure "Can't find server script for '${Server}'."
  exit 1
fi

declare -a Tunnels
declare -i NTunnels="${#LocalPorts[@]}"
for (( i = 0 ; i < $NTunnels ; ++i )); do
	LocalPort="${LocalPorts[i]}"
	DestServer="${DestServers[i]:-${DestServers[-1]}}"
	DestPort="${DestPorts[i]}"

	if isPortOpen "$LocalPort" ; then
	  # ListPort "$LocalPort" --process
	  Info "Port '${LocalPort}' appears to be already open (hopefully to ${DestServer}:${DestPort}...)."
	  continue
	fi

	Info "Opening a tunnel to ${DestServer}:${DestPort} through port ${LocalPort}."
	Tunnels+=( "${LocalPort}=>${DestServer}:${DestPort}" )
done

declare Date="$(date)"
if [[ "${#Tunnels[@]}" == 0 ]]; then
  Info "All ${NTunnels} tunnels appear to be already open."
else
  "$Server" tunnel "${Tunnels[@]}"
fi
declare -i nErrors=0
for (( i = 0 ; i < $NTunnels ; ++i )); do
  LocalPort="${LocalPorts[i]}"
  DestServer="${DestServers[i]:-${DestServers[-1]}}"
  DestPort="${DestPorts[i]}"
  if isPortOpen "$LocalPort" ; then
    Success "${Date} -- Server ${DestServer}:${DestPort} reached via ${LocalPort}."
  else
    Failure "${Date} -- It seems ${LocalPort} (to ${DestServer} port ${DestPort}) is still not open..."
    let nErrors+=1
  fi
done
[[ $nErrors -gt 0 ]] && exit 1
exit 0


################################################################################

