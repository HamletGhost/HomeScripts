#!/bin/sh
: ${CLIENT:="dhcp1"}
: ${PORT:="12345"}

: ${PLAYMP3:="mpg321"}
: ${NETCAT:="nc"}

"$PLAYMP3" -s - $OGGOPTS "$@" | "${NETCAT}" "$CLIENT" "$PORT"

