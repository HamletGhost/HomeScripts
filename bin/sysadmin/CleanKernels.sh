#!/bin/bash

CWD="$(pwd)"

declare -a Kernels
declare -a KernelDirs
declare -i NKernels=0
declare -i nErrors=0

for Dir in "$@" ; do
	KernelDir="${Dir%:}"
	[[ -d "$KernelDir" ]] || KernelDir="/usr/src/${KernelDir}"
	if [[ ! -d "$KernelDir" ]]; then
		echo "'${Dir}' is not a directory!" >&2
		let ++nErrors
		continue
	fi
	
	BaseDir="$(dirname "$KernelDir")"
	KernelRepoDir="$(basename "$KernelDir")"
	
	[[ "$KernelRepoDir" =~ ^linux-([^-]*)-([^-]*)(-(.*))?$ ]] || {
		echo "Can't parse the kernel information from the name '${KernelRepoDir}'"
		let ++nErrors
		continue
	}

	KernelVersion="${BASH_REMATCH[1]}"
	EbuildRevision="${BASH_REMATCH[4]}"
	EbuildVersion="${BASH_REMATCH[1]}${BASH_REMATCH[3]}"
	KernelType="${BASH_REMATCH[2]}"
	GentooPackageAtom="sys-kernel/${KernelType}-sources-${EbuildVersion}"
	
	echo "Cleaning: ${KernelRepoDir} (${GentooPackageAtom})"
	make -C "$KernelDir" distclean || {
		echo "Error ($?) cleaning the directory '${KernelDir}'!" >&2
		let ++nErrors
		continue
	}
	
	KernelDirs[NKernels]="$KernelDir"
	Kernels[NKernels]="=${GentooPackageAtom}"
	let ++NKernels
done

if [[ $NKernels == 0 ]]; then
	echo "Nothing left to do."
	exit $nErrors
fi

echo "Unmerging kernel sources: ${Kernels[@]}"
emerge --unmerge "${Kernels[@]}"
[[ $? == 0 ]] || echo "Error unmerging kernel sources!" >&2

for KernelDir in "${KernelDirs[@]}" ; do
	# the directory should have been removed; if it has no Makefile,
	# we silently remove it; otherwise, we complain
	if [[ -d "${KernelDir}/Makefile" ]]; then
		echo "Directory '${KernelDir}' was not properly cleaned."
		let ++nErrors
	else
		echo "Removing the leftovers of '${KernelDir}'..."
		rm -Rf "$KernelDir" || let ++nErrors
	fi
done

[[ $nErrors -gt 0 ]] && echo "${nErrors} errors encountered."
exit $nErrors
