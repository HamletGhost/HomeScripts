#!/usr/bin/env python
#
# Author: petrillo@fnal.gov
# Date:   20140310
# 
# Version:
# 1.0 (petrillo@fnal.gov)
#   first version
# 1.1 (petrillo@fnal.gov)
#   support for compressed input files;
#   swapped total and partial memory columns
# 1.2 (20140315 petrillo@fnal.gov)
#   added sorting, print of start and end of the region
# 2.0 (20241122 petrillo@slac.stanford.edu)
#   converted to Python3 (and argparse)
#

import sys, os
import gzip
try: import bz2
except ImportError: pass

import argparse

__version__ = "2.0"
__doc__ = """
ProcID can be either a running process ID (in which case a memory map
/procs/ProcID/maps is used), or directly the map in a file.

"""

SortKey_Size, SortKey_Start, SortKey_Path \
  = [ 'mapsize', 'start', 'path' ]

SortKeys = [ SortKey_Size, SortKey_Start, SortKey_Path ]
DefaultSort = SortKey_Size

################################################################################
class MapDataClass:
  def __init__(self, s):
    Tokens = s.split()
    self.address = Tokens[0]
    hexBegin, hexEnd = self.address.split('-')
    self.begin = int(hexBegin, 16)
    self.end = int(hexEnd, 16)
    self.perms = Tokens[1]
    self.offset = int(Tokens[2], 16)
    self.dev = Tokens[3]
    self.inode = int(Tokens[4])
    try:               self.path = Tokens[5]
    except IndexError: self.path = ""
  # __init__()
  
  def size(self): return self.end - self.begin
  def start(self): return self.begin
  def stop(self): return self.end
# class MapDataClass

class MapDataListClass:
  def __init__(self, name):
    self.data = []
    self.path = name
  # __init__()
  
  def __len__(self): return len(self.data)
  def __iter__(self): return iter(self.data)
  def __getitem__(self, index): return self.data[index]
  
  def append(self, datum):
    if datum: self.data.append(datum)
  
  @staticmethod
  def ComputeSize(data):
    s = 0
    for datum in data: s += datum.size()
    return s
  # ComputeSize()
  
  @staticmethod
  def ComputeRangeAndSize(data):
    if len(data) < 2: return 0
    start_sorted = sorted(data, None, lambda d: d.start(), True)
    
    size = MapDataListClass.ComputeSize(start_sorted)
    
    return start_sorted[0].start(), start_sorted[-1].stop(), size
  # ComputeRangeAndSize()
  
  @staticmethod
  def ComputeHole(data):
    begin, end, size = MapDataListClass.ComputeRangeAndSize(data)
    return end - begin - sizw
  # ComputeHole()
  
  def size(self): return self.ComputeSize(self.data)
  
  def hole(self): return self.ComputeHole(self.data)
  
  def start(self):
    if not self.data: return None
    if len(self.data) == 1: return self.data[0].start()
    
    size_sorted = sorted(self.data, None, lambda d: d.size())
  #  start_sorted = sorted(self.data, None, lambda d: d.start(), True)
    
    for iDatum in range(0, len(size_sorted) - 1):
      start, end, size = self.ComputeRangeAndSize(self.data[iDatum:])
      if (end - start) < 2*size: return start
    # for
    return None
  # start()
  
  def stop(self):
    if not self.data: return None
    if len(self.data) == 1: return self.data[0].stop()
    
    size_sorted = sorted(self.data, None, lambda d: d.size())
  #  end_sorted = sorted(self.data, None, lambda d: d.end(), True)
    
    for iDatum in range(0, len(size_sorted) - 1):
      start, end, size = self.ComputeRangeAndSize(self.data[iDatum:])
      if (end - start) < 2*size: return end
    # for
    return None
  # stop()
  
# class MapDataClass


def OPEN(Path, mode = 'r'):
  if Path.endswith('.bz2'): return bz2.BZ2File(Path, mode)
  if Path.endswith('.gz'): return gzip.GzipFile(Path, mode)
  return open(Path, mode)
# OPEN()

def PadStringLeft(s, padding): return " " * (padding - len(s)) + s


def PrintMemoryMap(ProcessMemPath, options):
  
  MapFile = OPEN(ProcessMemPath)
  
  nPages = 0
  TotalMemory = 0
  MemPages = []
  for line in MapFile:
    
    MemPage = MapDataClass(line.strip())
    MemPages.append(MemPage)
    
    size = MemPage.size()
    if size <= 0: continue
    
    nPages += 1
    TotalMemory += size
  # for
  
  # produce the list of items to print
  ItemsList = None
  if options.DontGroup:
    ItemsList = MemPages
  else:
    # group
    MappedMem = {}
    for MemPage in MemPages:
      try: MapDataList = MappedMem[MemPage.path]
      except KeyError:
        MapDataList = MapDataListClass(MemPage.path)
        MappedMem[MemPage.path] = MapDataList
      # try ... except
      MapDataList.append(MemPage)
    # for
    ItemsList = MappedMem.values()
  # if ... else
  
  # collect the items to be printed
  SortKeys = []
  TotalIndex = None
  SortKeyIndex = None
  Content = []
  for dataList in ItemsList:
    Items = [ "" ]
    if SortKeyIndex is None: SortKeys.append("")
    
    TotalIndex = len(Items)
    Items.append(dataList.size())
    if SortKeyIndex is None: SortKeys.append("")
    
    Items.append(f"{dataList.size()//1024:8d} KiB")
    if SortKeyIndex is None: SortKeys.append(SortKey_Size)
    
    if options.PrintStart:
      start = dataList.start()
      if start is None:
        Items.append("%18s" % "   (varies)   ")
      else:
        Items.append(PadStringLeft(f"0x{start:x}", 18))
      if SortKeyIndex is None: SortKeys.append(SortKey_Start)
    # if
    
    if options.PrintEnd:
      stop = dataList.stop()
      if stop is None:
        Items.append("%18s" % "   (varies)   ")
      else:
        Items.append(PadStringLeft(f"0x{stop}", 18))
      if SortKeyIndex is None: SortKeys.append(SortKey_Start)
    # if
    
    Items.append("|")
    if SortKeyIndex is None: SortKeys.append("")
    
    Items.append(dataList.path)
    if SortKeyIndex is None: SortKeys.append(SortKey_Path)
    
    Content.append(Items)
    
    if SortKeyIndex is None:
      SortKeyIndex = dict([ (k, i) for i, k in enumerate(SortKeys) ])
  # for
  
  # sort them
  for SortKey in reversed(options.Sort):
    if not SortKey: continue
    reverse = SortKey[0] in '!~-'
    if reverse: SortKey = SortKey[1:]
    try: sortIndex = SortKeyIndex[SortKey]
    except KeyError: raise Exception(f"Invalid sort key: '{SortKey}'")
    Content.sort(key=lambda r: r[sortIndex], reverse=True)
  # for
  
  # add the total
  if TotalIndex is not None:
    ProgressiveTotal = 0
    for row in Content:
      ProgressiveTotal += row[TotalIndex]
      row[TotalIndex] = f"{ProgressiveTotal//1024:8d} KiB"
    # for
  # if total
  
  # print
  for row in Content: print(" ".join(map(str, row)))
  
  # ... and a summary
  print(f"{ProcessMemPath}: {TotalMemory} bytes"
    f" ({TotalMemory/1048576:.2f} MiB) in {nPages} pages and {len(ItemsList)} groups")
  
  return TotalMemory
# PrintMemoryMap()


################################################################################
if __name__ == "__main__":
  
  Parser = argparse.ArgumentParser(description=__doc__)
  
  Parser.add_argument("PIDorMaps", nargs='+',
    help="one or more process IDs or map files")
  
  Parser.add_argument("-G", "--nogroup", dest="DontGroup", action="store_true",
    help="do not group the pages by node" )
  Parser.add_argument("-S", "--start", dest="PrintStart", action="store_true",
    help="prints the start address of the area" )
  Parser.add_argument("-E", "--end", dest="PrintEnd", action="store_true",
    help="prints the end address of the area" )
  Parser.add_argument("-s", "--sort", dest="Sort", action="append",
    default=[], help="sorts by the specified item ('help' for a list)" )
  Parser.add_argument("--unsorted", dest="DontSort", action="store_true",
    default=[], help="do not sort the entries at all" )
  Parser.add_argument("--version", "-v", action="version",
    version='%(prog)s ' + __version__)
  
  args = Parser.parse_args()
  
  if ('help' in args.Sort) or ('list' in args.Sort):
    print("Supported sort keys:", " ".join([ key for key in SortKeys if key ]))
    sys.exit(0)
  # if
  
  if args.DontSort and args.Sort:
    print("I am confused: should I sort, or not??", file=sys.stderr)
    sys.exit(1)
  # if
  
  if not args.DontSort and not args.Sort: args.Sort = [ DefaultSort ]
  
  nErrors = 0
  for ProcessSpec in args.PIDorMaps:
    
    try:
      ProcessID = int(ProcessSpec)
      ProcessMemMapFile = '/proc/%d/maps' % ProcessID
    except ValueError:
      ProcessMemMapFile = ProcessSpec
    
    if not os.path.exists(ProcessMemMapFile):
      print(f"No process memory map '{ProcessMemMapFile}' found.", file=sys.stderr)
      nErrors += 1
      continue
    # if no mem file
    
    try:
      PrintMemoryMap(ProcessMemMapFile, args)
    except Exception as e:
      print(f"Caught exception while processing '{ProcessMemMapFile}':\n{str(e)}",
        file=sys.stderr)
      nErrors += 1
      raise
      continue
    # try ... except
  # for
  
  sys.exit(max(nErrors, 1))
# main
