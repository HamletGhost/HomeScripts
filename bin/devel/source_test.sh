#!/usr/bin/env bash

cat <<-EOM
Command (with ${#} arguments): '$0' $@"
BASH_SOURCE (${#BASH_SOURCE[@]} elements): ${BASH_SOURCE[@]}
EOM

