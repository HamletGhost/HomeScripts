#!/bin/sh

: ${DestDir:="PackageSizes"}
: ${Force:=0}

mkdir -p "$DestDir"

equery list "*" | while read Package ; do
	PackageName="${Package##*/}"
	SizeFile="${DestDir}/${PackageName}.log"
	[[ -n "${Force//0}" ]] && rm -f "$SizeFile"
	[[ -r "$SizeFile" ]] && continue
	equery size "=${PackageName}" | sed -e 's/(/: /g' -e 's/)$//g' -e 's/)/ /g' > "$SizeFile"
	cat "$SizeFile"
done

find "$DestDir" -name "*.log" | xargs sort -k9 -g | less
