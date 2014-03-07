#!/bin/sh
#

PWD=pwd

if [ "${1}" == "-h" -o "${1}" == "--help" ]; then
	echo "${0}  command"
	echo "Executes the same command in this directory and all subdirectories."
	exit
fi

if [ "${0:0:1}" == "/" ]; then
	PATH_PREFIX=""
else
	PATH_PREFIX="../"
fi

echo "Descending into `${PWD}`..."
if [ ! -z "${1}" ]; then
	${1}
fi

for _d in * ; do
	if [ -d "$_d" -a "$_d" != "." -a "$_d" != ".." ]; then
		(cd "$_d" ; "${PATH_PREFIX}$0" "${1}")
	fi
done
