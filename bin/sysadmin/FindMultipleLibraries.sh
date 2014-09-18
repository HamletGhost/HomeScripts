#!/bin/sh

declare -a SearchPath

SearchPath=( "$@" )
[[ "${#SearchPath[@]}" == 0 ]] && SearchPath=( {,/usr}/lib{32,64} )

echo "Searching for duplicate libraries in directories: ${SearchPath[@]}" >&2

for LibBasePath in $(find "${SearchPath[@]}" -type f -name '*.so*' | sed 's/\.so\(\..*\|\)$/.so/' | sort | uniq -d ) ; do
	
	[[ -n "${SIMPLE//0}" ]] || echo "${LibBasePath} :"

	for LibFile in "$LibBasePath"* ; do
		[[ -h "$LibFile" ]] && continue
		Package="$(equery belongs "$LibFile")"
		if [[ -n "${SIMPLE//0}" ]]; then
			[[ -z "$Package" ]] && echo "$LibFile"
		else
			find "$LibFile" -printf "  %-40p (%t, %s bytes, ${Package:-"OLD!!!"})\n"
		fi
	done
done

