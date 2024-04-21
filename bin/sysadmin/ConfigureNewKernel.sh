#!/usr/bin/env bash

declare Cwd="$(pwd)"

declare -r BaseKernelDir="/usr/src"
declare -r CurrentKernelDirName="${1:-"linux"}"
declare -r ConfigFileName=".config"
declare -r KernelDirCheckFile="Kconfig"

declare CurrentKernelDir="$CurrentKernelDirName"
[[ "${CurrentKernelDirName:0:1}" != '/' ]] && CurrentKernelDir="${BaseKernelDir}/${CurrentKernelDir}"
declare -r CurrentKernelConfig="${CurrentKernelDir}/${ConfigFileName}"

declare -ir NCores="$(grep -c -E '^processor[[:blank:]]*:' /proc/cpuinfo)"

function STDERR() { echo "$*" >&2 ; }
function FATAL() {
  local -i Code="$1"
  shift
  STDERR "FATAL (${Code}): $*"
  exit "$Code"
} # FATAL()
function LASTFATAL() {
  local -ir Code="$?"
  [[ "$Code" == 0 ]] || FATAL "$Code" "$*"
} # LASTFATAL()

function isKernelSourceDir() {
	local Dir="${1:-.}"
	[[ -d "$Dir" ]] || return 1
	[[ -f "${Dir}/${KernelDirCheckFile}" ]] || return 1
	return 0
} # isKernelSourceDir()

if [[ ! -f "$NewConfig" ]] && ! isKernelSourceDir "$NewConfig" ; then
	# let's say we are not in the right directory, then;
	# and let's jump to the latest kernel directory
	LatestKernelDir="$(ls -d "${BaseKernelDir}/linux-"* | sort -rV | head -n 1)"
	LASTFATAL "Failed to detect the newest kernel source directory."
	echo "Using '${LatestKernelDir}' as kernel source."
	NewConfig="${LatestKernelDir}/.config"
fi


#
# checks
#
if ! isKernelSourceDir "$Cwd" ; then
	# let's say we are not in the right directory, then;
	# and let's jump to the latest kernel directory
	LatestKernelDir="$(ls -d "${BaseKernelDir}/linux-"* | sort -rV | head -n 1)"
	LASTFATAL "Failed to detect the newest kernel source directory (the current one, '${Cwd}', is not)."
	cd "$LatestKernelDir"
	Cwd="$(pwd)"
fi

[[ -d "$CurrentKernelDir" ]] || FATAL 2 "can't find the current kernel directory: '${CurrentKernelDir}'."

[[ -r "$CurrentKernelConfig" ]] || FATAL 2 "the current kernel configuration ('${CurrentKernelConfig}') is not available!!"

[[ "$Cwd" -ef "$CurrentKernelDir" ]] && FATAL 1 "this is the directory of the current kernel!"

declare -r NewLinuxKernelName="$(basename "$Cwd")"
echo "Configuring and compiling Linux kernel '${NewLinuxKernelName}'"

#
# copy the configuration from the existing kernel
#
if [[ ! -r "$ConfigFileName" ]] || [[ "$CurrentKernelConfig" -nt "$ConfigFileName" ]]; then
  echo "Copying the current kernel configuration to start from:"
  cp -v "$CurrentKernelConfig" "${Cwd}/${ConfigFileName}"
  LASTFATAL "failed to copy configuration file '${CurrentKernelConfig}'!"
else
  echo "The new kernel configuration seems to be newer than the current kernel configuration: we preserve it."
fi

#
# start the configuration
#

cat <<EOM
The graphic interface of the kernel configuration will now be started.
Please <Save> the configuration with the interface,
and then run \`CompareKernelConfig.sh\` from '${Cwd}' and update the configuration as needed.
When done, quit the configuration GUI and kernel compilation will start.

Running kernel configuration...
EOM
make menuconfig
LASTFATAL "failure running the kernel configuration."

#
# start the compilation
#
echo "Kernel compilation (${NCores} parallel jobs):"
make -j${NCores}
LASTFATAL "kernel compilation failed."

#
# closing remarks
#

echo "Compilation of kernel '${NewLinuxKernelName}' complete. Proceed with installation (\`cd \"${Cwd}\" && NewKernel.sh\`)."

exit 0

