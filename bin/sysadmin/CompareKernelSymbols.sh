#/!bin/sh
#
# Directions:
# 1) go to the source directory of the new kernel
# 2) copy the old one's configuration here: # cp /usr/src/linux/.config .
# 3) make it updated, e.g. run `make menuconfig` and save configuration withoutchanges
# 4) run this command (in this case, no parameters needed,
# 	but you can specify the path to the new configuration)

SCRIPTDIR="$(dirname "$0")"

: ${ExtractConfigSymbols:="KernelConfigSymbols.sh"}

: ${WSIZE:="${COLUMNS:-150}"}

BaseKernelDir='/usr/src'
NewConfig="${1:-.config}"
OldConfig="${2:-"${BaseKernelDir}/linux"}"

function isKernelSourceDir() {
	local Dir="$1"
	[[ -d "$Dir" ]] || return 1
	[[ -f "${Dir}/Kconfig" ]] || return 1
	return 0
} # isKernelSourceDir()

if [[ ! -f "$NewConfig" ]] && ! isKernelSourceDir "$NewConfig" ; then
	# let's say we are not in the right directory, then;
	# and let's jump to the latest kernel directory
	LatestKernelDir="$(ls -d "${BaseKernelDir}/linux-"* | sort -rV | head -n 1)"
	[[ $? != 0 ]] && echo "Failed to detect the newest kernel source directory." >&2 && exit 1
	echo "Using '${LatestKernelDir}' as kernel source."
	NewConfig="${LatestKernelDir}/.config"
fi

[[ -d "$OldConfig" ]] && OldConfig="${OldConfig%%/}/.config"
[[ -d "$NewConfig" ]] && NewConfig="${NewConfig%%/}/.config"

OldConfigReal="$(readlink -f "$OldConfig")"

if cmp -q "$OldConfig" "$NewConfig" >& /dev/null ; then
	echo "The two configuration files are the same (should you update one?)" >&2
	exit 1
fi

# first try to see if the files are the same:
diff -q -b <( sed -e '1,+4d' "$OldConfig") <( sed -e '1,+4d' "$NewConfig" ) >& /dev/null
if [[ $? == 0 ]]; then
	echo "Config files '${OldConfigReal}' (old) and '${NewConfig}' (new) completely match."
	exit 0
fi

diff -y -W ${WSIZE} --suppress-common-lines <("${SCRIPTDIR}/${ExtractConfigSymbols}" "$OldConfig") <("${SCRIPTDIR}/${ExtractConfigSymbols}" "$NewConfig") | less -x 8

