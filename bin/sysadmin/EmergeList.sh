#!/bin/sh

LISTFILE="$1"
LEFT="${LISTFILE}.todo"
TEMPFILE="$(mktemp "EmergeList.tmp.XXXXXX" )"

: ${EMERGEOPT:=""}

[[ -r "$LEFT" ]] || cp "$LISTFILE" "$LEFT"
INPUTFILE="${LEFT}.left"

cp -f "$LEFT" "$INPUTFILE"

TOTAL="$(wc -l "$LISTFILE" | awk '{ print $1 ; }')"
TODO="$(wc -l "$LEFT" | awk '{ print $1 ; }')"

echo "Emerging ${TODO}/${TOTAL} packages..."

while read ; do
	if [[ "${REPLY:0:1}" == '[' ]]; then
		PACKAGE="=$(echo "$REPLY" | sed -e 's/^\[.*\] \([^ ]*\) .*$/\1/')"
		FULLEMERGEOPT="$EMERGEOPT"
	else
		PACKAGE="$REPLY"
		FULLEMERGEOPT="$EMERGEOPT"
	fi
	echo "Emerging '$PACKAGE' ($((TOTAL - TODO + 1))/$TOTAL)"
	
	emerge $FULLEMERGEOPT "$PACKAGE" || break
	let --TODO
	cp "$LEFT" "$TEMPFILE"
	tail -n "$TODO" "$TEMPFILE" > "$LEFT"
done < "$INPUTFILE"

rm -f "$INPUTFILE" "$TEMPFILE"

