#!/bin/bash
#
# Removes comment lines from the input (files or stdin).
#

grep -v -e '^[[:blank:]]*#' "$@" | grep -v -e '^[[:blank:]]*$'

