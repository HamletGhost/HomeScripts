#!/usr/bin/env python

__doc__ = """Finds the newest kernel (by version number).
"""

import os
import re
import logging

class KernelVersion:
  def __init__(self, major, minor, patch, suffix = ""):
    self.major, self.minor, self.patch, self.suffix = major, minor, patch, suffix
  def __lt__(self, other):
    if self.major != other.major: return self.major < other.major
    if self.minor != other.minor: return self.minor < other.minor
    if self.patch != other.patch: return self.patch < other.patch
    # this is not fully correct
    if   self.suffix is None: return other.suffix is not None
    elif other.suffix is None: return False
    else: return self.suffix < other.suffix
  # __lt__()
# class KernelVersion

class KernelVersionParser:
  SourceDirPattern = re.compile(r"^linux-(\d+)(\.(\d+))?(\.(\d+))?(_(r|rc|p|pre)\d+)*(-.*)?$")
  def __call__(self, s):
    # quite simplified parsing here...
    if not (res := KernelVersionParser.SourceDirPattern.match(s)): return None
    return KernelVersion(
      int(res[1]) if res.lastindex >= 1 and res[1] is not None else None,
      int(res[3]) if res.lastindex >= 3 and res[3] is not None else None,
      int(res[5]) if res.lastindex >= 5 and res[5] is not None else None,
      res[6][1:]  if res.lastindex >= 6 and res[6] is not None else None,
      )
# class KernelVersionParser


def findNewestKernelDir(
  baseDir: "where to find kernel sources" = '/usr/src'
  ) -> "path of the latest kernel source relative to `baseDir` (None if none found)":
  
#  SourceDirPattern = re.compile("^linux-(\d+)(\.(\d+))?(\.(\d+))?(_([rp]\d+))?(-.*)?$")
  parser = KernelVersionParser() 
  with os.scandir(baseDir) as dirIter:
    LinuxSourceDirs = list(
#      ( res.groups()[::2], entryInfo )
      ( res, entryInfo )
      for entryInfo in dirIter
#      if entryInfo.is_dir() and (res := SourceDirPattern.match(entryInfo.name))
      if entryInfo.is_dir() and (res := parser(entryInfo.name))
      )
  # with
  
  LinuxSourceDirs.sort()
  
  logging.debug("Found %d Linux source directories:\n%s", 
                len(LinuxSourceDirs),
                "\n".join(item[1].name for item in LinuxSourceDirs)
                )
  
  return LinuxSourceDirs[-1][1] if LinuxSourceDirs else None
  
# findNewestKernelDir()


# ------------------------------------------------------------------------------
if __name__ == "__main__": 
  import sys
  import argparse
  
  logging.basicConfig()
  
  Parser = argparse.ArgumentParser(description=__doc__)
  
  Parser.set_defaults(basedir="/usr/src")
  
  Parser.add_argument("--basedir", help="kernel source base directory [%(default)s]")
  Parser.add_argument("--fullpath", "-p", action="store_true",
                      help="print full directory path instead of just its name"
                      )
  
  Parser.add_argument("--verbose", "-v", action="store_true",
                      help="print more information on screen"
                      )
  
  args = Parser.parse_args()
  
  if args.verbose: logging.getLogger().setLevel(logging.DEBUG)
  
  dirPath = findNewestKernelDir(baseDir=args.basedir)
  if not dirPath:
    logging.error("Could not find the newest Linux source directory.")
    sys.exit(1)
  
  print(dirPath.path if args.fullpath else dirPath.name)
  sys.exit(0)
# if

# ------------------------------------------------------------------------------
