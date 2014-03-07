#!/usr/bin/env python

import sys
import optparse
from bisect import bisect_left, bisect

UsageMsg = """%prog  [options] [number] [number]"""
Version = "%prog 1.0"

global Debug
Debug = 0

class ListsThenInput:
	def __init__(self, *inputs):
		self.bStdInputOnlyIfEmptyLists = False
		self.InputsIter = iter(inputs)
		if len(inputs) > 0: self.ListIter = iter(self.InputsIter.next())
		else: self.ListIter = None
		self.count = 0
		if Debug >= 1: print "%d inputs: %s" % (len(inputs), inputs)
	# __init__()
	
	def ReadStdInOnEmptyInput(self, bDoThat = True):
		self.bStdInputOnlyIfEmptyLists = bDoThat
	
	def __iter__(self): return self
	def next(self):
		# the internal iterators have already been initialized and they're
		# ready to be used; unless they have expired already, and then it's None
		
		while self.ListIter is not None:
			try:
				if Debug >= 1: print "Getting next value..."
				value = self.ListIter.next()
				self.count += 1
				return value
			except StopIteration:
				if Debug >= 2: print "  (failed)"
			# no more elements in this list, huh? what's next list?
			try:
				if Debug >= 1: print "Getting next iterator..."
				self.ListIter = self.InputsIter.next()
				if Debug >= 2: print "  (got %r)" % self.ListIter
				continue
			except StopIteration:
				if Debug >= 2: print "  (failed)"
			
			if self.bStdInputOnlyIfEmptyLists and self.count == 0:
				self.bStdInputOnlyIfEmptyLists = False # no more
				self.ListIter = iter(sys.stdin)
			else:
				self.ListIter = None
				raise StopIteration
		# while
		
		raise StopIteration
	# next()
	
	def __repr__(self):
		return "<%s count=%d>" % (self.__class__.__name__, self.count)
	
# class ListsThenInput


class SimpleRange:
	def __init__(self, lower = None, upper = None):
		self.lower = lower
		self.upper = upper
	# __init__()
	
	@staticmethod
	def NextValue(value): return value + 1
	
	def getUpperLimit(self):
		if self.upper is not None: return self.upper
		if self.lower is not None: return SimpleRange.NextValue(self.lower)
		return None
	# getUpperLimit()
	
	def last(self):
		if self.lower is None: return None
		if self.upper is None: return self.lower
		return self.upper - 1
	# last()
	
	def isIncluded(self, value):
		return self.lower is not None and value >= self.lower \
		  and value < self.getUpperLimit()
	# isIncluded()
	
	def isClose(self, value):
		return self.isIncluded(value) or (value == self.getUpperLimit())
	# isIncluded()
	
	def isJoint(self, SR):
		# False is the SR overlaps or touches this range
		return ((SR.lower is None) or self.isClose(SR.lower)) \
			or self.isClose(SR.getUpperLimit()) \
			or (self.lower is None or SR.isClose(self.lower)) \
			or SR.isClose(self.getUpperLimit())
	# isJoint()
	
	def isDisjoint(self, SR): return not self.isJoint(SR)
	
	def Extend(self, value, force=False):
		if not force and self.lower is not None and \
		  ((value < self.lower) or (value > self.getUpperLimit())):
			return False
		if self.lower is None: self.lower = value
		elif self.lower != value:
			self.upper = max(self.upper, SimpleRange.NextValue(value))
		return True
	# Extend()
	
	def Merge(self, SR):
		if SR.lower is None: return True
		if self.lower is None:
			self.lower = SR.lower
			self.upper = SR.upper
			return True
		if self.isDisjoint(SR): return False
		self.lower = min(self.lower, SR.lower)
		self.upper = max(self.upper, SimpleRange.NextValue(SR.lower), SR.upper)
		return True
	# Merge()
	
	def __len__(self):
		if self.lower is None: return 0
		if self.upper is None: return 1
		return self.upper - self.lower
	# __len__()
	
	def __iter__(self):
		if self.lower is None: return iter(list())
		if self.upper is None: return iter([self.lower])
		return iter(xrange(self.lower, self.upper))
	# __iter__()
	
	# comparisons are with (integral) numbers
	def __eq__(self, than): return self.lower == than
	def __ne__(self, than): return self.lower != than
	
	def __gt__(self, than):
		if self.lower is None or than is None: return None
		return self.lower > than
	# __gt__()
	def __lt__(self, than):
		if self.lower is None or than is None: return None
		return self.lower < than
	# __lt__()
	
	def __ge__(self, than):
		if self.lower is None: return than is None
		if than is None: return None
		return self.lower >= than
	# __ge__()
	
	def __le__(self, than):
		if self.lower is None: return than is None
		if than is None: return None
		return self.lower <= than
	# __le__()
	
	def __str__(self):
		if self.lower is None: return "[]"
		elif self.upper is None: return str(self.lower)
		else: return "%d-%d" % (self.lower, self.last())
	# __str__()
	
# class SimpleRange()


if __name__ == "__main__":
	
	Parser = optparse.OptionParser(usage=UsageMsg)
	
	Parser.add_option("-O", "--format", dest="PrintFormat", default="linear",
	  help="linear, sums, columnsums or columns [%default]")
	Parser.add_option("-i", "--input", "--inputfile", dest="InputFileNames",
	  default=[], action="append", help="read input also from this file")
	Parser.add_option("-S", "--nostdin", dest="NoStdIn", action="store_true",
	  default=False,
	  help="don't read from stdin if there is no other input [%default]")
	Parser.add_option("-d", "--debug", dest="Debug", type="int", default=0,
	  help="verbosity level [%default]")
	
	(options, Specs) = Parser.parse_args()
	
	Debug = options.Debug
	
	InputFiles = []
	
	for InputFileName in options.InputFileNames:
		if len(InputFileName) == 0 or InputFileName == '-':
			InputFile = sys.stdin
		else:
			InputFile = open(InputFileName, 'r')
		InputFiles.append(InputFile)
	# for
	
	Ranges = []
	
	InputIter = ListsThenInput(Specs, *InputFiles)
	InputIter.ReadStdInOnEmptyInput(not options.NoStdIn)
	
	for iLine, line in enumerate(InputIter):
		line = line.strip()
		
		if Debug >= 1: print line
		
		for iToken, token in enumerate(line.split()):
			if token.startswith('#'): break
			
			try: value = int(token)
			except ValueError:
				print >>sys.stderr, "Word %d of line %d is not a number (%r)" \
				  % (iToken+1, iLine+1, token)
			
			if Debug >= 1:
				print "Current range before line %d word %d: %r" \
				  % (iLine, iToken, ", ".join([ str(SR) for SR in Ranges]))
			
			if Debug >= 2: print "[#%d] got %d" % (iToken, value)
			
			if len(Ranges) == 0: iRange = 0
			else: iRange = bisect_left(Ranges, value)
			
			if Debug >= 2: print "Next range: #%d" % iRange
			
			# lets's see if we can extend the range we found
			if iRange < len(Ranges) and Ranges[iRange].Extend(value):
				if Debug >= 2:
					print "Merging to the range (now %s)" % Ranges[iRange]
				continue
			if iRange > 0 and Ranges[iRange-1].Extend(value):
				if Debug >= 2:
					print "Merging to the previous range (now %s)" % Ranges[iRange-1]
				continue
			
			if Debug >= 2: print "Inserting a new range"
			Ranges.insert(iRange, SimpleRange(value))
			
		# for token
		
	# for line
	
	MergedRanges = []
	LastRange = None
#	print "Before merging: %s" % (", ".join([ str(SR) for SR in Ranges]), )
	
	for SR in Ranges:
		if Debug >= 2: print "Include %s" % SR
		if LastRange is None or not LastRange.Merge(SR):
			MergedRanges.append(SR)
			if Debug >= 1: 
				print \
				  "-> Added: %s" % (", ".join([ str(SR) for SR in MergedRanges]))
			LastRange = SR
		else:
			if Debug >= 1:
				print \
				  "-> Merged: %s" % (", ".join([ str(SR) for SR in MergedRanges]))
	# for
	
	if options.PrintFormat == "sums":
		print "%d merged values: %s" % (sum([ len(SR) for SR in MergedRanges ]),
		  ", ".join([ "%s (%d)" % (SR, len(SR)) for SR in MergedRanges]))
	elif options.PrintFormat == "linear":
		print "Merged values: %s" \
		  % (", ".join([ str(SR) for SR in MergedRanges ]))
	elif options.PrintFormat == "columnsums":
		for SR in MergedRanges:
			if SR.upper is None: print 1, SR.lower
			else: print len(SR), SR.lower, SR.last()
		# for
	else:
		for SR in MergedRanges:
			if SR.upper is None: print SR.lower
			else: print SR.lower, SR.last()
		
	sys.exit(0)
# main()