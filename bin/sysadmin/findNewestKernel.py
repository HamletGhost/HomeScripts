#!/usr/bin/env python

__doc__ = """Finds the newest kernel (by version number).
"""

import os
import re
import logging

def findNewestKernelDir(
  baseDir: "where to find kernel sources" = '/usr/src'
  ) -> "path of the latest kernel source relative to `baseDir` (None if none found)":
  
  SourceDirPattern = re.compile("^linux-(\d+)(\.(\d+))?(\.(\d+))?(_([rp]\d+))?(-.*)?$")
  
  with os.scandir(baseDir) as dirIter:
    LinuxSourceDirs = list(
      ( res.groups()[::2], entryInfo )
      for entryInfo in dirIter
      if entryInfo.is_dir() and (res := SourceDirPattern.match(entryInfo.name))
      )
  # with
  
  LinuxSourceDirs.sort()
  
  logging.debug("Found %d Linux source directories:\n%s", 
                len(LinuxSourceDirs),
                "\n".join(item[1].name for item in LinuxSourceDirs)
                )
  
  return LinuxSourceDirs[-1][1].name if LinuxSourceDirs else None
  
# findNewestKernelDir()


# ------------------------------------------------------------------------------
if __name__ == "__main__": 
  import sys
  import argparse
  
  logging.basicConfig()
  
  Parser = argparse.ArgumentParser(description=__doc__)
  
  Parser.set_defaults(basedir="/usr/src")
  
  Parser.add_argument("--basedir", help="kernel source base directory [%(default)s]")
  
  Parser.add_argument("--verbose", "-v", action="store_true",
                      help="print more information on screen"
                      )
  
  args = Parser.parse_args()
  
  if args.verbose: logging.getLogger().setLevel(logging.DEBUG)
  
  dirPath = findNewestKernelDir(baseDir=args.basedir)
  if not dirPath:
    logging.error("Could not find the newest Linux source directory.")
    sys.exit(1)
  
  print(dirPath)
  sys.exit(0)
# if

# ------------------------------------------------------------------------------
