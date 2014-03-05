#!/bin/sh
: ${CLIENT:="dhcp1"}
: ${PORT:="12345"}

: ${PLAYDVD:="mplayer"}
: ${NETCAT:="nc"}

: ${SOURCE:="${1:-1}"}
: ${VIDEOOPT:="-vo null"}

[[ -n "$TITLE" ]] && SOURCE="${TITLE}/${SOURCE}"

# first parameter is title, if any
shift

TEMPFILE="$(mktemp)"
rm -f "$TEMPFILE"

mkfifo "$TEMPFILE"
cat "$TEMPFILE" | "$NETCAT" "$CLIENT" "$PORT" &
"$PLAYDVD" $VIDEOOPT -ao "pcm:nowaveheader:file=$TEMPFILE" "dvd://$SOURCE"

rm -f "$TEMPFILE"

