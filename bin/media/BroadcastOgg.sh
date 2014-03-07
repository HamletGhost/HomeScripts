#!/bin/sh
: ${CLIENT:="dhcp1"}
: ${PORT:="12345"}

: ${PLAYOGG:="ogg123"}
: ${NETCAT:="nc"}

"$PLAYOGG" -d raw -f - $OGGOPTS "$@" | "${NETCAT}" "$CLIENT" "$PORT"

