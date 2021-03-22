#!/usr/bin/env bash

function Xport() {
  # if Port is specified ( [host:]port[.screen] ), use it;
  # otherwise attempt autodetection;
  # always be verbose...
  local Port="$1"
  
  local -r Autodetect=1 # maybe one day we'll want this optional
  
  local RecommendedHost
  local RecommendedPort
  local RecommendedScreen
  local RecommendedDisplay

  if [[ "$Autodetect" != 0 ]]; then
 
    # find a way to autodetect the right port
    if [[ -n "$TMUX" ]]; then
      # we are in tmux environment: let's ask tmux
      DisplayLine="$(tmux show-env | grep -E '^DISPLAY=')"
    
      if [[ "$DisplayLine" =~ DISPLAY=(.*):([0-9]+)\.([0-9]+) ]]; then
        RecommendedHost="${BASH_REMATCH[1]}"
        RecommendedPort="${BASH_REMATCH[2]}"
        RecommendedScreen="${BASH_REMATCH[3]}"
        RecommendedDisplay="${RecommendedHost}:${RecommendedPort}.${RecommendedScreen}"
      fi
    else
      : # no other smart way...
    fi
  fi # if autodetection

  if [[ -n "$Port" ]]; then
    [[ "${Port//.}" == "$Port" ]] && Port+=".0"
    [[ "${Port//:}" == "$Port" ]] && Port="localhost:${Port}"
  fi

  local Display="${Port:-${RecommendedDisplay}}"
  if [[ -z "$Display" ]]; then
    echo "ERROR: no port specified, and auto-detection failed." >&2
    return 1
  fi

  if [[ "$DISPLAY" == "$Display" ]]; then
    echo "DISPLAY already set to ${Display}."
  else
    
    if [[ -z "$DISPLAY" ]]; then
      echo "Display was not set."
    elif [[ "$DISPLAY" =~ localhost:([0-9]+)\.([0-9]+) ]]; then
      echo "Display was set on port ${BASH_REMATCH[1]}."
    else
      echo "Display was set as '${DISPLAY}'."
    fi
 
    export DISPLAY="$Display"
    echo "DISPLAY now set to '${DISPLAY}'."
  fi
  if [[ -n "$RecommendedDisplay" ]] && [[ "$RecommendedDisplay" != "$Display" ]]; then
    echo "Warning: DISPLAY recommended setting is '${RecommendedDisplay}'."
  fi
  return 0
} # Xport()

