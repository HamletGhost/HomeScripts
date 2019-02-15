#!/usr/bin/env bash

find "$@" -type f -printf '%CY%Cm%Cd%CH%CM%CS %Cc %p\n' | sort -k1 -g | sed -e 's/^[^ ]* *//'

