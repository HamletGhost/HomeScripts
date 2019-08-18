#!/usr/bin/env python3

import sys
import math # sqrt()

__doc__ = """
Sums all the numbers provided to it in input.

If specified, source files are read in place of standard input; if a '-' is
specified as input, standard input is used in place of that file.

Input lines made exclusively of the following (case-insensitive) keywords are
considered commands (this feature needs to be turned on):
- 'p', '=', 'partial': prints the current result
- 'r', 'reset', 'clear': clears the sum and restarts
- 'q', 'quit', 'exit': quits
"""
__version__ = "1.1"


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
		self.min_ = None
		self.max_ = None
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
		if self.min_ is None or value < self.min_: self.min_ = value
		if self.max_ is None or value > self.max_: self.max_ = value
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
	def min(self): return self.min_
	def max(self): return self.max_
# class Stats


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
	print(" ".join(PrintedList))
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
		if ColNumber: print("[{}] ".format(iStat+1), end='')
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
	import argparse
	
	Parser = argparse.ArgumentParser(description=__doc__)
	
	Parser.set_defaults(bFloat=True, bCommands=False, Print=[], ColNumber=None)
	
	Parser.add_argument("sources", nargs='*', help="source files")
	
	argGroup = Parser.add_argument_group(title="Numerical output format")
	argGroup.add_argument("--integer", "-d", "-i", action="store_false",
	  dest="bFloat", help="sets the sum of integral numbers")
	argGroup.add_argument("--real", "--float", "-e", "-f", "-g", 
	  action="store_true", dest="bFloat", help="sets the sum of real numbers")
	argGroup.add_argument("--enable-commands", "-C", action="store_true",
	  dest="bCommands", help="enables special commands (see help)")
	argGroup.add_argument("--radix", type=int, dest="Radix", default=0,
		help="radix of integer numbers (0: autodetect) [%(default)d]")
	
	argGroup = Parser.add_argument_group(title="Output arrangement")
	
	columnOptions = argGroup.add_mutually_exclusive_group()
	columnOptions.add_argument("--columns", "-c", 
		action="append", dest="Columns", default=[],
		help="sets column mode and the columns to be included, comma separated"
			" (first is 1)")
	columnOptions.add_argument("--allcolumns",
		action="store_true", dest="AllColumns", default=False,
		help="sets column mode and uses all available columns")
  
	argGroup.add_argument("--colnumber", "-l", 
		action="store_true", dest="ColNumber",
		help="writes the column number in the output [default: only when needed]")
	argGroup.add_argument("--nocolnumber", "-L",
		action="store_false", dest="ColNumber",
		help="omits the column number in the output [default: only when needed]")
	
	argGroup = Parser.add_argument_group(title="Statistics output")
	argGroup.add_argument("--average", "-a",
		dest="Print", action="append_const", const="average",
		help="prints the average of the input")
	argGroup.add_argument("--sum", "-s",
		dest="Print", action="append_const", const="sum",
		help="prints the sum of the input")
	argGroup.add_argument("--sumsq", "-q",
		dest="Print", action="append_const", const="sumsq",
		help="prints the sum of the squares of the input")
	argGroup.add_argument("--rms",
		dest="Print", action="append_const", const="rms",
		help="prints the root mean square of the input")
	argGroup.add_argument("--rms2",
		dest="Print", action="append_const", const="rms2",
		help="prints the mean square difference of the input")
	argGroup.add_argument("--stdev",
		dest="Print", action="append_const", const="stdev",
		help="prints the standard deviation of the input")
	argGroup.add_argument("--stdevp",
		dest="Print", action="append_const", const="stdevp",
		help="prints the deviation of the full population of the input")
	argGroup.add_argument("--min", "-m",
		dest="Print", action="append_const", const="min",
		help="prints the minimum value encountered")
	argGroup.add_argument("--max", "-M",
		dest="Print", action="append_const", const="max",
		help="prints the maximum value encountered")
	
	Parser.add_argument('--version', action="version",
		version="%(prog)s version {}".format(__version__)
		)
	
	
	args = Parser.parse_args()
	
	if not args.Print: args.Print = [ "sum" ]
	
	Columns = [ int(c.strip()) for c in ExpandList(args.Columns, ",") ]
	Columns.sort()
	
	if args.AllColumns and len(Columns) > 0:
		Parser.error("Can't have --columns and --allcolumns options together.")
	
	ColNumber = args.ColNumber
	
	sources = args.sources
	if len(sources) == 0: sources = [ '-' ] # add stdin as default
	bFloat = args.bFloat
	
	nErrors = 0
	
	stats = ResetStats(Columns, args)
	
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
					print("Couldn't open input file '{}'.".format(sname), file=sys.stderr)  
					continue
			# if ... else
			
			iLine = 0
			for line in source:
				Command = line.strip().lower()
				
				# parse for special commands
				if args.bCommands:
					isCommand = True
					if   Command in [ '=', 'p', 'partial', ]:
						PrintAllResults(stats, ColNumber, args)
					elif Command in [ 'r', 'c', 'reset', 'clear', ]:
						stats = ResetStats(Columns, args)
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
						else: value = int(word, args.Radix)
						if args.AllColumns:
							while iWord > len(stats): stats.append(Stats(bFloat))
							stats[iWord-1].add(value)
						elif len(Columns) > 0: stats[iWord - 1].add(value)
						else: stats[0].add(value)
					except ValueError:
						print(
						  "Not a number in input file '{}' word #{} line {} ('{}')."
						  .format(sname, iWord, iLine, word),
                                                  file=sys.stderr
                                                  )
						nErrors += 1
				# for words
				
				if args.ColNumber is None:
					ColNumber \
					  = len(Columns) > 1 or (args.AllColumns and len(stats) > 1)
				iLine += 1
			# for source
			
			if source is not sys.stdin: source.close()
		# for sname
	except MultiBreak: pass
	
	PrintAllResults(stats, ColNumber, args)
	
	if nErrors > 0:
		print(nErrors, "errors found.", file=sys.stderr)
		sys.exit(1)
	sys.exit(0)
# end of program
