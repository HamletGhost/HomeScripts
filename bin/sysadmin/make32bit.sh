#!/usr/bin/env bash
#
# Iterates runs of `emerge <package>`, detects missing 32-bit ABI USE flags,
# and adds them to the packages reported by emerge as needing them.
# Each run produces its own file named after the `<package>`.
#

SCRIPTNAME="$(basename "${BASH_SOURCE[0]}")"

declare -r UseFileDir='/etc/portage/package.use'
declare -r Flag='abi_x86_32'

################################################################################
function PrintHelp() {
  cat <<EOH
Recursively adds 32-bit USE flag ('${Flag}') to make the specified package compile with 32-bit ABI.

Usage:  ${SCRIPTNAME}  [options]  PackageAtom

The package atom is in a format understood by \`emerge\`.
A new file is created in '${UseFileDir}' named after the package, and in there
USE flags '${Flag}' are added to all the packages that require it and don't have
it yet.

Options:
--skip-primary , -S
    by default, the PackageAtom specified on the command line (the "primary" one)
    is always added as first entry of the file, with '${Flag}' flag;
    if this option is specified, the primary package flags are not changed.
--help , -h , -?
    prints this message

EOH

} # PrintHelp()


################################################################################
function isFlagSet() {
  local VarName="$1"
  [[ -n "${!VarName//0}" ]]
} # isFlagSet()

function STDERR() { echo "$*" >&2 ; }
function FATAL() {
  local Code="$1"
  shift
  STDERR "FATAL (${Code}): $*"
  exit $Code
} # FATAL()

function Cleanup() {
  [[ -n "$LogFile" ]] && rm -f "$LogFile"
} # Cleanup()

function ExpandPackageName() {
  # Expands the first argument into a full package name

  local Key="$1"

  [[ "$Key" =~ / ]] && echo "$Key" && return 0 # it looks already complete

  # we assume that the only missing thing is the category name... so let's find it out

  local EbuildPath
  EbuildPath="$(equery which "$Key")" || return $?
  
  # rely on the fact that ebuild are stored in .../category-name/package directory
  local TempPath="$(dirname "$EbuildPath")"
  local PackageName="$(basename "$TempPath")" # who cares anyway
  TempPath="$(dirname "$TempPath")"
  local CategoryName="$(basename "$TempPath")"
  
  echo "${CategoryName}/${Key}"

} # ExpandPackageName()


function AddPackages() {
  local UseFile="$1"
  shift
  local -a Additions
  touch "$UseFile"
  local Package
  for Package in "$@" ; do
    grep -wq "$Package" "$UseFile" || Additions+=( "$Package" )
  done
  for Package in "${Additions[@]}" ; do
    echo "Adding: '${Package}'"
    echo "${Package} ${Flag}" >> "$UseFile"
  done
} # AddPackages

function ExtractPackageName() {
  # example:
  # "- x11-libs/libxcb-1.13.1::gentoo (Change USE: +abi_x86_32)"
  
  local Line="$1"
  [[ "$Line" =~ [[:blank:]]([^/]*)/(.*)-[0-9].* ]] || return 1
  echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  return 0
} # ExtractPackageName

################################################################################

###
###  Parameter parsing
###
declare -a Parameters
declare -i SkipPrimary=0
declare -i NoMoreOptions=0
for (( iParam = 1 ; iParam <= $# ; ++iParam )); do
  Param="${!iParam}"
  if isFlagSet NoMoreOptions || [[ "${Param:0:1}" != '-' ]]; then
    Parameters+=( "$Param" )
    case "${#Parameters[@]}" in
      ( 1 ) PackageKey="$Param" ;;
      ( * ) FATAL 1 "Too many parameters, starting with #${iParam} ('${Param}')."
    esac
  else
    case "$Param" in
      ( '--skip-primary' | '-S' ) SkipPrimary=1 ;;
      ( '--help' | '-h' | '-?' ) DoHelp=1 ; ExitCode=0 ;; 
      ( '--' | '-' ) NoMoreOptions=1 ;;
      ( * )
        FATAL 1 "Unsupported option #${iParam}: '${Param}'."
    esac
  fi
done

if isFlagSet DoHelp ; then
  PrintHelp
  [[ -n "$ExitCode" ]] && exit ${ExitCode}
fi

Target="$(ExpandPackageName "$PackageKey")" || FATAL $? "Failed to identify the correct package."

###
###  Preparation
###
trap Cleanup EXIT
LogFile="$(mktemp --tmpdir "${SCRIPTNAME}-log.tmp.XXXXXX")"
declare UseFile="${UseFileDir%/}/$(tr '/:' '_' <<< "$Target")-32bit"
declare -i AppendToFile=0
[[ -r "$UseFile" ]] && AppendToFile=1
declare AppendWord1=''
isFlagSet AppendToFile && AppendWord1=' more' # cosmetic

###
###  Attempt loop
###

declare -i nAttempts=0
while true ; do
  let ++nAttempts
  Cmd=( 'emerge' '--color' 'y' '-DuNpv' "$Target" )
  echo "Attempt #${nAttempts}: ${Cmd[@]}"
  "${Cmd[@]}" >& "$LogFile"
  res=$?
  [[ $res == 0 ]] && break
  ErrorMsg="$(grep -E -e "\\(Change USE: .*\\+${Flag}.*\\)" "$LogFile")"
  [[ -z "$ErrorMsg" ]] && break
  
  if [[ $nAttempts == 1 ]]; then
    echo "Adding${AppendWord1} more USE flag '${Flag}' to packages via '${UseFile}':"
    if isFlagSet AppendToFile ; then
      echo "# adding more packages ($(date))" >> "$UseFile"
    else
      echo "Adding USE flag '${Flag}' to packages via '${UseFile}':"
      echo "# adding packages for '${Target}' ($(date))" >> "$UseFile"
      [[ "$SkipPrimary" ]] || echo "${Target}" >> "$UseFile"
    fi
  fi
  
  Package="$(ExtractPackageName "$ErrorMsg")"
  if [[ $? != 0 ]]; then
    STDERR "Can't discover the package name from line '${ErrorMsg}'" >&2
    break
  fi
  
  AddPackages "$UseFile" "$Package"

done
cat "$LogFile"
[[ $nAttempts -gt 1 ]] && echo >> "$UseFile" # trailing empty line, for convenience
if [[ $res == 0 ]]; then
  [[ $Attempts -gt 1 ]] && echo "32 bit mode enabled for $((nAttempts - 1))${AppendWord1} packages."
  echo "'${Target}' appears to be ready to be merged."
else
  STDERR "Unable to automatically prepare the installation of '${Target}' in 32-bit mode."
fi
exit $res


