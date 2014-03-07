#!/bin/sh

: ${OUTPUTPORT:="VGA"}
: ${RESOL:="1024x768"}
xrandr --output LVDS --mode "1280x800" --output "$OUTPUTPORT" --below LVDS --mode "$RESOL"
