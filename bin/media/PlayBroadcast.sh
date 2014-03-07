#!/bin/sh

: ${PLAY:="aplay"}
: ${NETCAT:="nc"}

: ${PORT:="12345"}

# : ${SERVERNAME:="dhcp1"}
# : ${SERVERPORT:="12345"}

$NETCAT -l -p "$PORT" $SERVERNAME $SERVERPORT | $PLAY -f cd $PLAYOPTS

