#!/usr/bin/env bash

# ------------------------------------------------------------------------------
function setupArea() {
  #
  # Executes a local setup.
  # 
  # The local setup is expected in:
  #  * ./setupArea.sh
  #
  # The protocol for the script `setupArea.sh` is:
  #  * a function `DoSetup` must be defined, which runs the full setup.
  #
  
  local Cwd="$(pwd)"
  local res=0
  
  # in the future, there may be more names/formats to be supported
  local SetupFile="setupArea.sh"
  
  if [[ ! -f "$SetupFile" ]]; then
    echo "No supported setup script found in '${Cwd}'." >&2
    return 2
  fi
  
  # check the protocol:
  (
    source "$SetupFile"
    declare -f DoSetup >& /dev/null
  )
  res=$?
  if [[ $res != 0 ]]; then
    echo "The setup script '${SetupFile}' does not define a \`DoSetup\` function." >&2
    return 1
  fi
  
  source "$SetupFile"
  DoSetup "$@"
  res=$?
  if [[ $res != 0 ]]; then
    # restore what we can
    cd "$Cwd"
    echo "Setup ('${SetupFile}') exited with code ${res}." >&2
  fi
  
  return $res
  
} # setupArea()


# ------------------------------------------------------------------------------
function goAndSetupArea() {
  #
  # Performs `setupArea` in the directory specified by the first argument.
  # That argument is removed, and all others are passed to `setupArea`.
  #
  
  local WorkDir="$1"
  if [[ ! -d "$WorkDir" ]]; then
    echo "Invalid directory: '${WorkDir}'." >&2
    return 2
  fi
  shift
  cd "$WorkDir"
  setupArea "$@"
  
} # goAndSetupArea()


# ------------------------------------------------------------------------------
