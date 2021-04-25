#!/bin/bash
#

###  local variables  #########################################################
: ${ARCH="x86_64"}
: ${KSOURCEDIR:="/usr/src/linux"}
: ${KERNELDIR:="${KSOURCEDIR}/arch/${ARCH}/boot"}
: ${KERNELNAME:="bzImage"}
: ${SYSTEMNAME:="Gentoo"}
: ${BOOTDEV:="/boot"}
: ${BOOTBASEDIR:="${BOOTDEV}/Linux"}
: ${BOOTKERNELNAME:="vmlinuz"}
: ${BOOTCONFIGNAME:="config"}
: ${GRUBMENUNAME:="grub.cfg"}
: ${GRUBMENU:="${BOOTDEV}/grub/${GRUBMENUNAME}"}
: ${EDITOR:="vi"}
: ${GREP:="grep"}
: ${CP:="cp -fv"}
: ${MKDIR:="mkdir -p"}
: ${TOUCH:="touch"}
: ${DRACUT:="dracut"}
###############################################################################

PROGRAMNAME=`basename $0`
CWD="$(pwd)"

declare -a FLAGS=( 'FIRMWARE' 'COPYKERNEL' 'BOOTLOADER' 'INITRD' 'SELECTKERNEL' 'REBUILD' )


function help() {
	cat <<EOF

Installs a new kernel.

Usage:  $PROGRAMNAME  [options]

This script copies the kernel in current kernel tree or in the newest one
into boot directory.

Options:
-s SUFFIX , --suffix=SUFFIX  ['${SUFFIX}']
	specifies a kernel suffix
--only=FLAG[,FLAG...]
	only performs the specified steps. Valid flags are:
	${FLAGS[@]}
--force
	forces an operation even if we believe it is not needed

EOF
} # help()


function isFlagSet() {
	local FLAG="$1"
	[[ -n "${!FLAG//0}" ]]
}

function isFlagUnset() {
	local FLAG="$1"
	[[ -z "${!FLAG//0}" ]]
}

function isInList() {
	local Key="$1"
	for Value in "$@" ; do
		[[ "$Value" == "$Key" ]] && return 0
	done
	return 1
} # isInList()

function isDebug() {
	isFlagSet DEBUG
}


function STDERR() { echo "$*" >&2 ; }

function DBG() {
	isDebug && echo "$*"
}

function ERROR() { STDERR "Error: $*" ; }

function FAIL() {
	EXITCODE="$1"
	shift
	if [ -z "$*" ]; then
		echo "Fatal error; exiting." 1>&2
	else
		echo "Fatal error: $*." 1>&2
	fi
	remount_ro
	exit $EXITCODE
} # FAIL()


function remount() {
	mount -o remount,${1} "$BOOTDEV"
}

function remount_rw() {
	remount rw
}

function remount_ro() {
	[ -z "$READWRITE" ] && remount ro
}


function ExtractVersion() {
	SRCDIR="$1"
	echo "$SRCDIR" | sed -e 's@^.*linux-\([0-9]\+\)\.\([0-9]\+\)\.\([0-9]\+\)-\([^-]*\)\(-r\([0-9]\+\)\)\?\(/.*\)\?$@( \1 \2 \3 \4 \6 )@'
}

function PrintVar() {
	VARNAME="$1"
	DBG "$VARNAME = '${!VARNAME}'"
}

function PrintVars() {
	for VAR in "$@" ; do
		PrintVar "$VAR"
	done
}

function MakeInitRAMFS() {
	local DestPath="$1"
	local KernelVersion="$2"
	shift 2
	
	# look for the IWL firmware
	local LatestIWLfw="$(ls -rt /lib64/firmware/iwl*.ucode 2> /dev/null | tail -n 1)"
	[[ -r "$LatestIWLfw" ]] && echo "Including: '${LatestIWLfw}'"

	# create the thing
	local -a Cmd=( $DRACUT --force --lvmconf --hostonly ${LatestIWLfw:+--install "$LatestIWLfw"} "$DestPath" $UNAMER "$@" )
	echo "${Cmd[@]}"
	local res
	"${Cmd[@]}"
	res=$?
	if [[ $res == 0 ]]; then
		if [[ -r "$DestPath" ]]; then
			echo "InitRAMFS image created at '${DestPath}'"
		else
			echo "${Cmd[0]} ran successfully, yet there is no '${DestPath}'."
			return 2
		fi
	fi
	return $res
} # MakeInitRAMFS


function isFlagDefined() {
	local VarName="$1"
	[[ -n "${!VarName}" ]]
} # isFlagDefined()

function OnlyAction() { isFlagSet "ONLY_${1}" ; }

function DoAction() { isFlagSet "DO_${1}" ; }

function DateTag() { date '+%Y%m%d' ; }

###############################################################################
###  script starts here  ######################################################

DATETAG="$(datetag)"

declare -i iOnly=0
declare -a DoOnly

declare -i NoMoreOptions=0
declare -a Params
declare -i NParams

for (( iParam = 1 ; iParam <= $# ; ++iParam )); do
	Param="${!iParam}"
	if isFlagSet NoMoreOptions || [[ "${Param:0:1}" != '-' ]]; then
		Params[NParams++]="$Param"
	else
		case "$Param" in
			( '--suffix='* )
				SUFFIX="${Param#--suffix=}"
				;;
			( '-s' )
				let ++iParam
				SUFFIX="${!iParam}"
				;;
			( '--only='* )
				OnlySpecs="${Param#--only=}"
				for OnlyOption in ${OnlySpecs//,/ } ; do
					DoOnly[iOnly++]="$OnlyOption"
				done
				;;
			( '--force' )
				FORCE=1
				;;
			( '--help' | '-h' | '-?' )
				DoHelp=1
				;;
			( '-' | '--' )
				NoMoreOptions=1
				;;
			( * )
				ERROR "Unknown option '${Param}'."
				DoHelp=1
				;;
		esac
	fi
done

if [[ $NParams -gt 0 ]]; then
	ERROR "No command line argument is supported beside options."
	DoHelp=1
fi

if isFlagSet DoHelp ; then
	help
	exit 1
fi


for OnlyOption in "${DoOnly[@]}" ; do
	isInList "$OnlyOption" "${Flags[@]}" || FAIL 1 "Action flag '${OnlyOption}' not supported!"
	export ONLY_${OnlyOption}=1
done


###############################################################################
### set action flags
### 

for FlagName in "${FLAGS[@]}" ; do
	isFlagDefined "DO_${FlagName}" || export "DO_${FlagName}"=1
done

EXCLUSIVE_MODE=0
for FlagName in "${FLAGS[@]}" ; do
	if OnlyAction "$FlagName" ; then
		EXCLUSIVE_MODE=1
		break
	fi
done 
if isFlagSet EXCLUSIVE_MODE ; then
	for FlagName in "${FLAGS[@]}" ; do
		if OnlyAction "$FlagName" ; then
			export "DO_${FlagName}"=1
		else
			export "DO_${FlagName}"=0
		fi
	done
fi
	

###############################################################################
### extract kernel version
### 
KERNELDIR="$CWD"
[[ -h "$CWD" ]] && KERNELDIR="$(readlink "$CWD")"

if [[ ! "$KERNELDIRNAME" =~ ^linux ]]; then
  # not in a Linux source directory already: let's pick the newest one if we can
  
  KERNELDIR=''
  
  findNewestKernel="$(which 'findNewestKernel.py' 2> /dev/null )"
  if [[ $? == 0 ]]; then
    
    KERNELDIR="$( "$findNewestKernel" --fullpath )"
    if [[ $? == 0 ]]; then
      echo "Latest kernel source directory detected: '${KERNELDIR}'."
    else
      ERROR "Could not find the latest Linux kernel source."
    fi
    
  else
    ERROR "Script to detect the latest Linux kernel source not found."
  fi
  
  KERNELDIRNAME="$(basename "$KERNELDIR")"

fi

UNAMER="${KERNELDIRNAME#linux-}"

echo "New kernel: ${UNAMER}"

declare -a KVERSION[0]
eval KVERSION=$(ExtractVersion "$KERNELDIRNAME")

if isDebug ; then
	ExtractVersion "$KERNELDIRNAME"
	DBG "KVERSION=${KVERSION[*]}"
fi

KNAME=${KVERSION[3]:-"sources"}
KMAJOR=${KVERSION[0]}
KMINOR=${KVERSION[1]}
KPATCH=${KVERSION[2]}

###############################################################################
### set directory paths
### 
BOOTDIR="${BOOTBASEDIR}/${SYSTEMNAME}-${KMAJOR}.${KMINOR}/${KNAME}.${KPATCH}"
KERNELDIR="$KSOURCEDIR-$KMAJOR.$KMINOR.$KPATCH-$KNAME"
if [ -z "$SUFFIX" ] && [ -n "${KVERSION[4]}" ] ; then
	SUFFIX="-r${KVERSION[4]}"
	KSUFFIX=".r${KVERSION[4]}"
else
	KSUFFIX="$SUFFIX"
fi

[ -n "$SUFFIX" ] && KERNELDIR="${KERNELDIR}${SUFFIX}"

KERNELPATH="$KERNELDIR/arch/$ARCH/boot/$KERNELNAME"
[ -r "$KERNELPATH" ] || FAIL 2 "Can't find kernel '$KERNELPATH'"

# remount boot device read/write
if ! "$TOUCH" "${BOOTDIR}/${BOOTKERNELNAME}${KSUFFIX}" >& /dev/null ; then
	remount rw || FAIL 1 "can't remount $BOOTDEV read/write"
else
	READWRITE=1
fi

KERNELINSTALLPATH="${BOOTDIR}/${BOOTKERNELNAME}${KSUFFIX}"

###############################################################################
### firmware installation
### 
if DoAction FIRMWARE ; then
	echo "Reinstalling modules and firmware..."
	make modules_install firmware_install
else
	echo "Skipping installation of firmware"
fi

###############################################################################
### copy kernel
### 
if DoAction COPYKERNEL ; then
	# create destination directory
	${MKDIR} "${BOOTDIR}"
	
	# copy kernel
	${CP} "${KERNELPATH}" "$KERNELINSTALLPATH" || FAIL 1 "can't copy kernel file"
	
	# copy configuration file
	${CP} "${KERNELDIR}/.config" "${BOOTDIR}/${BOOTCONFIGNAME}${KSUFFIX}" || FAIL 1 "can't copy kernel configuration file"

	# overwrite (!) System.map
	${CP} "${KERNELDIR}/System.map" "${BOOTDIR}/System.map" || ERROR "Couldn't copy System.map!"
else
	echo "Skipping copy of kernel"
fi

###############################################################################
### create the init RAM disk
### 
if DoAction INITRD ; then
	# ask dracut to create a new initramfs
	if which "$DRACUT" >& /dev/null ; then
		INITRAMFSPATH="${BOOTDIR}/initramfs${SUFFIX}.img"
		echo "Creating '${INITRAMFSPATH}' for linux ${UNAMER}"
		MakeInitRAMFS "$INITRAMFSPATH" "$UNAMER"
	else
		echo "No dracut executable found, skipping RAM disk." >&2
	fi
else
	echo "Skipping creation of the initialization RAM disk"
fi


###############################################################################
### update boot loader
###
if DoAction BOOTLOADER ; then
	# edit grub if needed
	if [[ -r "$GRUBMENU" ]] && "$GREP" -q -- "${KERNELINSTALLPATH/$BOOTDEV}" "$GRUBMENU" && isFlagUnset FORCE ; then
		echo "$GRUBMENU seems to already have this kernel in."
	else
		echo "Running automatic GRUB configuration update..."
		NewGrubMenu="${GRUBMENU}-${UNAMER}-${DATETAG}"
		grub-mkconfig -o "$NewGrubMenu"
		res=$?
		if [[ $res == 0 ]]; then
			if [[ -r "$GRUBMENU" ]]; then
				OldGrubMenu="${GRUBMENU}-prev"
				echo "Previous grub menu saved as: '${OldGrubMenu}'"
				mv "$GRUBMENU" "$OldGrubMenu"
			else
				mkdir -p "$(dirname "$GRUBMENU")"
			fi
			mv "$NewGrubMenu" "$GRUBMENU"
		else
			FAIL $res "Creation of grub menu failed with exit code ${res}. Partial new menu saved as '${NewGrubMenu}'"
		fi
	fi
else
	echo "Skipping update of boot loader..."
fi

# remount boot device read only
remount_ro

###############################################################################
### selection of the system kernel
###

if DoAction SELECTKERNEL ; then
	echo "Selecting the new kernel..."
	eselect kernel set "$KERNELDIRNAME"
else
	echo "Skipping selection of kernel..."
fi
eselect kernel show


###############################################################################
### rebuild packages with kernel modules
###
if DoAction REBUILD ; then
	echo "Rebuilding modules..."
	emerge -1 --keep-going @module-rebuild
else
	echo "Skipping rebuild of packages with modules..."
fi

###############################################################################
echo "All done."

