#!/bin/sh
: ${CLIENT:="dhcp1"}
: ${PORT:="12345"}

: ${PLAYFLAC:="flac"}
: ${NETCAT:="nc"}

"$PLAYFLAC" -d -c $FLACOPTS "$@" | "${NETCAT}" "$CLIENT" "$PORT"

