#!/bin/bash

declare Server='vpn.fnal.gov'
declare VPNUser='petrillo@services.fnal.gov'
declare PIDFile="/var/run/openconnect-${VPNUser}-${Server}.pid"

sudo /usr/sbin/openconnect --background --pid-file="$PIDFile" --user="$VPNUser" --setuid="$USER" "$Server"

