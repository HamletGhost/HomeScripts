#!/usr/bin/env bash
#
# swapFiles.sh PathA PathB [PathC ...]
#
# PathB becomes PathA, PathC becomes PathB, etc.; PathA becomes the last specified path.
#

declare -a FilePaths=( "$@" )

# check that all exist
declare -a MissingPaths
for Path in "${FilePaths[@]}" ; do
  [[ -r "$Path" ]] || MissingPaths+=( "$Path" )
done

if [[ "${#MissingPaths[@]}" -gt 0 ]]; then
  echo "Missing ${#MissingPaths[@]} paths:" >&2
  printf " - '%s'\n" "${MissingPaths[@]}" >&2
  exit 2
fi

if [[ "${#FilePaths[@]}" -lt 2 ]]; then
  echo "At least two paths need to be specified." >&2
  exit 1
fi

# place the temporary file in the same place as the first file;
# with some luck, it will be just a rename.
WorkDir="$(dirname "${FilePaths[0]}")"
TmpFilePath="$(mktemp --tmpdir="$WorkDir" --dry-run "${SCRIPTNAME}.tmp.XXXXXX")" || exit $?

declare -i Error=0
declare -ar SourcePaths=( "${FilePaths[@]}" "$TmpFilePath" )
declare -ar DestPaths=( "$TmpFilePath" "${FilePaths[@]}" )
declare -i NMoves="${#SourcePaths[@]}"
for (( iPath = 0 ; iPath < $NMoves ; ++iPath )); do
  SourcePath="${SourcePaths[iPath]}"
  DestPath="${DestPaths[iPath]}"
  [[ "$SourcePath" -ef "$DestPath" ]] && echo "${SourcePath} and ${DestPath} are the same object: skipped." && continue
  mv --no-clobber --verbose "$SourcePath" "$DestPath"
  res=$?
  [[ $res != 0 ]] && Error=1 && break
done

if [[ $Error != 0 ]] && [[ $iPath -gt 0 ]]; then
  echo "An error occurred: attempting to undo the changes already applied!"
  while [[ $iPath -gt 0 ]]; do
    let --iPath
    SourcePath="${SourcePaths[iPath]}"
    DestPath="${DestPaths[iPath]}"
    [[ "$SourcePath" -ef "$DestPath" ]] && continue
    [[ -r "$DestPath" ]] || continue
    [[ -r "$SourcePath" ]] && continue
    mv --no-clobber --verbose "$DestPath" "$SourcePath"
  done
  exit $res
fi

exit 0
