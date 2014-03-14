#!/usr/bin/env python2
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
#

import sys, os
import gzip
try: import bz2
except ImportError: pass

import optparse

Version = "%prog 1.1"
UsageMsg = """%prog  [options] ProcID [ProcID ...]

ProcID can be either a running process ID (in which case a memory map
/procs/ProcID/maps is used), or directly the map in a file.

"""

################################################################################
class MapDataClass:
	def __init__(self, s):
		Tokens = s.split()
		self.address = Tokens[0]
		hexBegin, hexEnd = self.address.split('-')
		self.start = int(hexBegin, 16)
		self.stop = int(hexEnd, 16)
		self.perms = Tokens[1]
		self.offset = int(Tokens[2], 16)
		self.dev = Tokens[3]
		self.inode = int(Tokens[4])
		try:               self.path = Tokens[5]
		except IndexError: self.path = ""
	# __init__()
	
	def size(self): return self.stop - self.start
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
	
	def size(self):
		s = 0
		for datum in self.data: s += datum.size()
		return s
	# size()
	
# class MapDataClass


def OPEN(Path, mode = 'r'):
	if Path.endswith('.bz2'): return bz2.BZ2File(Path, mode)
	if Path.endswith('.gz'): return gzip.GzipFile(Path, mode)
	return open(Path, mode)
# OPEN()


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
		ItemsList = sorted([ (v.size(), v) for v in MemPages ])
		
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
		
		ItemsList = sorted([ (v.size(), v) for v in MappedMem.values() ])
	# if ... else
	
	# print the list of items
	ProgressiveTotal = 0
	for sortKey, dataList in ItemsList:
		ProgressiveTotal += dataList.size()
		print " %8d KiB %8d KiB | %s" % (
		  ProgressiveTotal/1024, dataList.size() / 1024, dataList.path
		  )
	# for
	
	# ... and a summary
	print "%s: %d bytes (%.2f MiB) in %d pages and %d groups" % (
	  ProcessMemPath, TotalMemory, TotalMemory/1048576., nPages, len(ItemsList)
	  )
	
	return TotalMemory
# PrintMemoryMap()


################################################################################
if __name__ == "__main__":
	
	Parser = optparse.OptionParser(usage=UsageMsg, version=Version)
	
	Parser.add_option("-G", "--nogroup", dest="DontGroup", action="store_true",
	  default=False, help="do not group the pages by node" )
	
	(options, ProcessSpecs) = Parser.parse_args()
	
	nErrors = 0
	for ProcessSpec in ProcessSpecs:
		
		try:
			ProcessID = int(ProcessSpec)
			ProcessMemMapFile = '/proc/%d/maps' % ProcessID
		except ValueError:
			ProcessMemMapFile = ProcessSpec
		
		if not os.path.exists(ProcessMemMapFile):
			print >>sys.stderr, \
			  "No process memory map '%s' found." % ProcessMemMapFile
			nErrors += 1
			continue
		# if no mem file
		
		try:
			PrintMemoryMap(ProcessMemMapFile, options)
		except Exception, e:
			print >>sys.stderr, "Caught exception while processing '%s':\n%s" \
			  % (ProcessMemMapFile, e)
			nErrors += 1
			raise
			continue
		# try ... except
	# for
	
	sys.exit(nErrors)
# main
