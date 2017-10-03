#!/usr/bin/env bash

declare DeleteCmd=""
[[ -z "${FAKE//0}" ]] && DeleteCmd='-delete'

find "${@:-.}" '(' -name '.DS_Store' -or -name '._.DS_Store' ')' -ls ${DeleteCmd:+"$DeleteCmd"}

