#!/bin/bash

declare Server='vpn.fnal.gov'
# declare VPNUser='petrillo@services.fnal.gov'
declare VPNUser='petrillo'
declare VPNGroup='SiteVPN-RSA'
declare PIDFile="/var/run/openconnect-${VPNUser}-${Server}.pid"
 
declare -a ServerCerts=(
#  'pin-sha256:YuGjyXELNTCeOF0K2dcBk6tBedNJNNHH34Yhb5u2eIo='
#  'pin-sha256:xYUKRSEdpUFXNW+JubtPOTOqemN1CC8nmwEs8ym5z2g='
  )

declare -a ServerCertOpts
for ServerCert in "${ServerCerts[@]}" ; do
  ServerCertOpts+=( --servercert="$ServerCert" )
done

sudo /usr/sbin/openconnect \
  --background --pid-file="$PIDFile" \
  --user="$VPNUser" ${VPNGroup:+--authgroup="$VPNGroup"} \
  --setuid="$USER" \
  "${ServerCerts[@]}" \
  "$Server"

