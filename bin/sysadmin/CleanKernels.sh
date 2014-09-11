#!/bin/bash

CWD="$(pwd)"

declare -a Kernels
declare -a KernelDirs
declare -i NKernels=0
declare -i nErrors=0

for Dir in "$@" ; do
	KernelDir="$Dir"
	[[ -d "$KernelDir" ]] || KernelDir="/usr/src/${KernelDir}"
	if [[ ! -d "$KernelDir" ]]; then
		echo "'${Dir}' is not a directory!" >&2
		let ++nErrors
		continue
	fi
	
	BaseDir="$(dirname "$KernelDir")"
	KernelRepoDir="$(basename "$KernelDir")"
	
	KernelVersionAndType="${KernelRepoDir#linux-}"
	if [[ "$KernelVersionAndType" == "$KernelRepoDir" ]]; then
		echo "Directory '${KernelDir}' does not look like a kernel source directory." >&2
		let ++nErrors
		continue
	fi
	
	KernelVersion="${KernelVersionAndType%-*}"
	KernelType="${KernelVersionAndType#${KernelVersion}-}"
	GentooPackageAtom="sys-kernel/${KernelType}-sources-${KernelVersion}"
	
	echo "Cleaning: ${KernelRepoDir} (${GentooPackageAtom})"
	cd "$KernelDir"
	make distclean
	res=$?
	cd "$CWD"
	if [[ $res != 0 ]]; then
		echo "Error cleaning the directory '${KernelDir}'!" >&2
		let ++nErrors
		continue
	fi
	
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
	# the directory should have been removed; if it's empty,
	# we silently remove it; otherwise, we let rmdir complain
	if [[ -d "$KernelDir" ]]; then
		rmdir "$KernelDir" || let ++nErrors
	fi
done

[[ $nErrors -gt 0 ]] && echo "${nErrors} errors encountered."
exit $nErrors
