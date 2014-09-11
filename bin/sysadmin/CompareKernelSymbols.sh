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

: ${WSIZE:="150"}

NewConfig="${1:-.config}"
OldConfig="${2:-"/usr/src/linux"}"

[[ -d "$OldConfig" ]] && OldConfig="${OldConfig%%/}/.config"
[[ -d "$NewConfig" ]] && NewConfig="${NewConfig%%/}/.config"

if cmp -q "$OldConfig" "$NewConfig" >& /dev/null ; then
	echo "The two configuration files are the same (should you update one?)" >&2
	exit 1
fi

# first try to see if the files are the same:
diff -b <( sed -e '1,+4d' "$OldConfig") <( sed -e '1,+4d' "$NewConfig" ) >& /dev/null
if [[ $? == 0 ]]; then
	echo "Config files '${OldConfig}' (old) and '${NewConfig}' (new) completely match."
	exit 0
fi

diff -y -W ${WSIZE} --suppress-common-lines <("${SCRIPTDIR}/${ExtractConfigSymbols}" "$OldConfig") <("${SCRIPTDIR}/${ExtractConfigSymbols}" "$NewConfig") | less -x 8

