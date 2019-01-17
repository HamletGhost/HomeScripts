#!/usr/bin/env bash

function Xport() {
  declare Port="$1"
  
  # TODO: find a way to autodetect the right port
  if [[ -z "$Port" ]]; then
    cat <<EOH
Please specify which port to set for DISPLAY.
EOH
    return 1
  fi
  
  [[ "${Port//.}" == "$Port" ]] && Port+=".0"
  
  export DISPLAY="localhost:${Port}"
  
  return 0
} # Xport()

