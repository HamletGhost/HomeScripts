#!/usr/bin/env python

import sys
import math # sqrt()
import optparse

UsageMsg = """
\t%prog [options] [source] [source] [...]

Sums all the numbers provided to it in input.

If specified, source files are read in place of standard input; if a '-' is
specified as input, standard input is used in place of that file.

Input lines made exclusively of the following (case-insensitive) keywords are
considered commands (this feature needs to be turned on):
- 'p', '=', 'partial': prints the current result
- 'r', 'reset', 'clear': clears the sum and restarts
- 'q', 'quit', 'exit': quits
"""

class MultiBreak: pass

def signed_sqrt(value):
	if value >= 0.: return math.sqrt(value)
	else: return -math.sqrt(-value)
# signed_sqrt()


class Stats:
	def __init__(self, bFloat = True):
		self.clear(bFloat)
	
	def clear(self, bFloat = True):
		self.e_n = 0
		if bFloat:
			self.e_w = 0.
			self.e_sum = 0.
			self.e_sumsq = 0.
		else:
			self.e_w = 0
			self.e_sum = 0
			self.e_sumsq = 0
	# clear()
	
	def add(self, value, weight=1):
		"""Add a new item.
		
		The addition is treated as integer only if both value and weight are
		integrals.
		"""
		self.e_n += 1
		self.e_w += weight
		self.e_sum += weight * value
		self.e_sumsq += weight * value**2
	# add()
	
	def n(self): return self.e_n
	def weights(self): return self.e_w
	def sum(self): return self.e_sum
	def sumsq(self): return self.e_sumsq
	def average(self):
		if self.e_w != 0.: return float(self.e_sum)/self.e_w
		else: return 0.
	def sqaverage(self):
		if self.e_w != 0.: return float(self.e_sumsq)/self.e_w
		else: return 0.
	def rms2(self): return self.sqaverage() - self.average()**2
	def rms(self): return signed_sqrt(self.rms2())
	def stdev(self):
		if self.e_n < 2: return 0.
		else: return self.rms() * math.sqrt(float(self.e_n)/(self.e_n-1))
	def stdevp(self): return self.rms()
# class Stats


def append_const(option, opt_str, value, parser, *larg, **kwarg):
	keyword = larg[0]
	try: PrintList = getattr(parser.values, option.dest)
	except AttributeError: # but you should add an empty default value yourself
		PrintList = []
		setattr(parser.values, option.dest, PrintList)
	PrintList.append(keyword)
# append_const()


def PrintResults(stats, printlist):
	PrintedList = []
	for key in printlist:
		try:
			func = getattr(stats, key)
			res = func()
			if isinstance(res, int): res = "%d" % res
			else: res = "%g" % res
		except AttributeError:
			res = "['%s' not supported]" % key
		PrintedList.append(res)
	print " ".join(PrintedList)
# PrintResults()


def ExpandList(l, sep = None):
	el = []
	for item in l:
		if isinstance(item, str): el.extend(item.split(sep))
		else: el.append(item)
	# for
	return el
# ExpandList()


def PrintAllResults(stats, ColNumber, options):
	for iStat, stat in enumerate(stats):
		if stat is None: continue
		if ColNumber: print "[%d] " % (iStat+1),
		PrintResults(stat, options.Print)
	# for
# PrintAllResults()

def ResetStats(Columns, options):
	if options.AllColumns: stats = []
	elif len(Columns) == 0: stats = [ Stats(options.bFloat) ]
	else:
		stats = [ None ] * Columns[-1]
		for iCol in Columns: stats[iCol-1] = Stats(options.bFloat)
	return stats
# ResetStats()


# begin of program
if __name__ == "__main__":
	Parser = optparse.OptionParser(usage=UsageMsg, version="0.2")
	
	Parser.set_defaults(bFloat=True, bCommands=False, Print=[], ColNumber=None)
	
	Parser.add_option("-d", "-i", "--integer", action="store_false",
	  dest="bFloat", help="sets the sum of integral numbers")
	Parser.add_option("-e", "-f", "-g", "--real", "--float",
	  action="store_true", dest="bFloat", help="sets the sum of real numbers")
	Parser.add_option("-C", "--enable-commands", action="store_true",
	  dest="bCommands", help="enables special commands (see help)")
	
	Parser.add_option("-c", "--columns",
		action="append", dest="Columns", default=[],
		help="sets column mode and the columns to be included, comma separated"
			" (first is 1)")
	Parser.add_option("--allcolumns",
		action="store_true", dest="AllColumns", default=False,
		help="sets column mode and uses all available columns")
	Parser.add_option("-l", "--colnumber",
		action="store_true", dest="ColNumber",
		help="writes the column number in the output [default: only when needed]")
	Parser.add_option("-L", "--nocolnumber",
		action="store_false", dest="ColNumber",
		help="omits the column number in the output [default: only when needed]")
	Parser.add_option("--radix", type="int", dest="Radix", default=0,
		help="radix of integer numbers (0: autodetect) [%default]")
	
	Parser.add_option("-a", "--average",
		action="callback", callback=append_const, callback_args=("average",),
		dest="Print",
		help="prints the average of the input")
	Parser.add_option("-s", "--sum",
		action="callback", callback=append_const, callback_args=("sum",),
		dest="Print",
		help="prints the sum of the input")
	Parser.add_option("-q", "--sumsq",
		action="callback", callback=append_const, callback_args=("sumsq",),
		dest="Print",
		help="prints the sum of the squares of the input")
	Parser.add_option("--rms",
		action="callback", callback=append_const, callback_args=("rms",),
		dest="Print",
		help="prints the root mean square of the input")
	Parser.add_option("--rms2",
		action="callback", callback=append_const, callback_args=("rms2",),
		dest="Print",
		help="prints the mean square difference of the input")
	Parser.add_option("--stdev",
		action="callback", callback=append_const, callback_args=("stdev",),
		dest="Print",
		help="prints the standard deviation of the input")
	Parser.add_option("--stdevp",
		action="callback", callback=append_const, callback_args=("stdevp",),
		dest="Print",
		help="prints the deviation of the full population of the input")
	
	
	(options, sources) = Parser.parse_args()
	
	if len(options.Print) == 0: options.Print = [ "sum" ]
	
	Columns = [ int(c.strip()) for c in ExpandList(options.Columns, ",") ]
	Columns.sort()
	
	if options.AllColumns and len(Columns) > 0:
		Parser.error("Can't have --columns and --allcolumns options together.")
	
	ColNumber = options.ColNumber
	
	if len(sources) == 0: sources = [ '-' ] # add stdin as default
	bFloat = options.bFloat
	
	nErrors = 0
	
	stats = ResetStats(Columns, options)
	
	iFile = 0
	try:
		for sname in sources:
			iFile += 1
			if sname == '-':
				sname = "stdin"
				source = sys.stdin
			else:
				try:
					source = open(sname, 'r')
				except:
					print >>sys.stderr, "Couldn't open input file '%s'." % sname
					continue
			# if ... else
			
			iLine = 0
			for line in source:
				Command = line.strip().lower()
				
				# parse for special commands
				if options.bCommands:
					isCommand = True
					if   Command in [ '=', 'p', 'partial', ]:
						PrintAllResults(stats, ColNumber, options)
					elif Command in [ 'r', 'c', 'reset', 'clear', ]:
						stats = ResetStats(Columns, options)
					elif Command in [ 'q', 'quit', 'exit', ]:
						raise MultiBreak
					else:
						isCommand = False
					if isCommand: continue
				# if using special commands
				
				iWord = 0
				for word in line.strip().split():
					iWord += 1
					if len(Columns) > 0 and iWord not in Columns: continue
					try:
						if bFloat: value = float(word)
						else: value = int(word, options.Radix)
						if options.AllColumns:
							while iWord > len(stats): stats.append(Stats(bFloat))
							stats[iWord-1].add(value)
						elif len(Columns) > 0: stats[iWord - 1].add(value)
						else: stats[0].add(value)
					except ValueError:
						print >>sys.stderr, \
						  "Not a number in input file '%s' word #%d line %d ('%s')." \
						  % (sname, iWord, iLine, word)
						nErrors += 1
				# for words
				
				if options.ColNumber is None:
					ColNumber \
					  = len(Columns) > 1 or (options.AllColumns and len(stats) > 1)
				iLine += 1
			# for source
			
			if source is not sys.stdin: source.close()
		# for sname
	except MultiBreak: pass
	
	PrintAllResults(stats, ColNumber, options)
	
	if nErrors > 0:
		print >>sys.stderr, nErrors, "errors found."
		sys.exit(1)
	sys.exit(0)
# end of program
