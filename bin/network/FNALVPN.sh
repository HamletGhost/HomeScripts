#!/bin/bash

SCRIPTNAME="$(basename "$0")"

declare Server='vpn.fnal.gov'
declare Server='v-main-gcca-1-outside.fnal.gov'
# declare VPNUser='petrillo@services.fnal.gov'
declare VPNUser='petrillo'
declare VPNGroup='SiteVPN-RSA'
declare PIDFile="/var/run/openconnect-${VPNUser}-${Server}.pid"
 
declare -a ServerCerts=(
#  'pin-sha256:YuGjyXELNTCeOF0K2dcBk6tBedNJNNHH34Yhb5u2eIo='
  'pin-sha256:xYUKRSEdpUFXNW+JubtPOTOqemN1CC8nmwEs8ym5z2g='
  )

# ==============================================================================
function PrintHelp() {
  cat <<EOH
Fermilab VPN connection management (openconnect).

Usage:  ${SCRIPTNAME} [options]

This script opens a VPN connection to Fermilab. By default it's oblivious of
whether another connection exists.


Supported options:
--disconnect , --close , -D
    disconnects from an ongoing Fermilab VPN session, and does not open another
--reconnect , -C
    first disconnects from any ongoing Fermilab VPN session, then opens a new one
--help , -h , -?
    prints this help message

EOH
} # PrintHelp()


# ==============================================================================
declare -i DoHelp=0 Verbose=0
declare -i DoConnect=1 DoDisconnect=0
declare -i NoMoreParameters=0
for (( iParam = 1 ; iParam <= $# ; ++iParam )); do
  Param="${!iParam}"
  if [[ "$NoMoreParameters" == 0 ]] && [[ "${Param:0:1}" == '-' ]]; then
    case "$Param" in
      ( '--close' | '--disconnect' | '-D' ) DoConnect=0 ; DoDisconnect=1 ;;
      ( '--reconnect' | '-C' )              DoConnect=1 ; DoDisconnect=1 ;;
      ( '--verbose' | '--debug' | '-v' )    Verbose=1 ;;
      ( '--help' | '-h' | '-?' )            DoHelp=1 ;;
      ( * )
        echo "Unsupported option ('${Param}')." >&2
        ExitCode=1
    esac
  else
    echo "Unsupported positional parameter ('${Param}')" >&2
    ExitCode=1
  fi
done

# ------------------------------------------------------------------------------
if [[ "$DoHelp" != 0 ]]; then
  PrintHelp
  : ${ExitCode:=0}
fi

[[ -n "$ExitCode" ]] && exit "$ExitCode"

# ------------------------------------------------------------------------------
if [[ "$DoDisconnect" != 0 ]]; then
  
  if [[ ! -s "$PIDFile" ]]; then
    echo "No VPN connection ongoing (according to the absence of '${PIDFile}')."
    exit
  fi
  
  cat <<EOB

Disconnection to VPN '${Server}' in progress...

EOB
  
  sudo pkill --pidfile "$PIDFile"
  sudo rm -f "$PIDFile"
  
fi

if [[ $DoConnect != 0 ]]; then
  cat <<EOB

Connection to VPN '${Server}' in progress...

EOB
  declare -a ServerCertOpts
  for ServerCert in "${ServerCerts[@]}" ; do
    ServerCertOpts+=( --servercert="$ServerCert" )
  done

  declare -a Cmd=( /usr/sbin/openconnect
    --background --pid-file="$PIDFile"
    "${ServerCertOpts[@]}"
    --user="$VPNUser" ${VPNGroup:+--authgroup="$VPNGroup"}
    --setuid="$USER"
    "$Server"
    )

  [[ "$Verbose" == 0 ]] || echo "CMD> ${Cmd[@]}"
  sudo "${Cmd[@]}"

fi

