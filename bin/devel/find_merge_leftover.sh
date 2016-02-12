#!/usr/bin/env bash
#
# Prints names of all files with GIT merge leftover marks.
#

function DetectMergeLeftover() {
   local File="$1"
   [[ -r "$File" ]] || return 2
   
   grep -q -e '^<<<<<<<' -e '^|||||||' -e '^=======$' -e '^>>>>>>>' -- "$File"
   [[ $? != 0 ]] && return 0
   
   echo "${File#./}"
   return 1
} # DetectMergeLeftover()

function ParseDir() {
   local Dir="$1"
   [[ -d "$Dir" ]] || return 2
   
   local -i nFound=0
   local Path
   find "$Dir" -type f | while read Path ; do
      [[ "$(basename "Path")" == '.git' ]] && continue # skip GIT directories
      DetectMergeLeftover "$Path"
      [[ $? == 1 ]] && let ++nFound
   done
   [[ $nFound == 0 ]]
} # ParseDir()


################################################################################
declare -a Paths=( "$@" )

[[ "${#Paths[@]}" == 0 ]] && Paths=( '.' )

for Path in "${Paths[@]}" ; do
   if [[ -f "$Path" ]]; then
      DetectMergeLeftover "$Path"
   else
      ParseDir "$Path"
   fi
done
