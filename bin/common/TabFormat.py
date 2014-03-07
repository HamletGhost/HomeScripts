#!/usr/bin/env python
# -*- coding: iso-8859-1 -*-

import sys
import os # os.path.basename()
import optparse
import fileinput

Version = "%prog 1.0"
UsageMsg = """
\t%prog  [options] [Sources]

Replaces all tab characters with spaces, providing a fixed alignment.

Each tabulate specification can be the absolute position of the column ("8")
or the incremental position respect to the previous one in the same
specification ("8,+7"), in which case a number of times can be specified
("8+7*3", equivalent to "8,+7,+7,+7"). The first tab stop must be absolute (you
can use "0,+7*3", though).
Specifications can be set in the same command line parameter separated by a
comma, or they can be specified with multiple command line parameters.
After the list of tab stops is built, it is sorted."""

DebugLevel = 0


def ConvertLine(line, Tabs, LastTabSize, filler = " ", rfiller = None):
	if len(filler) == 0: filler = ' '
	
	s = ""
	LastTab = 0
	for iC, c in enumerate(line):
		if c != '\t': s += c
		else:
			if DebugLevel > 0:
				print "DBG| <TAB> found at #%d" % iC
				print "DBG| string %d char long so far: %r" % (len(s), s)
			
			pos = len(s)
			# find which tab we are at now
			while LastTab < len(Tabs) and Tabs[LastTab] <= pos: LastTab += 1
			
			if LastTab >= len(Tabs):
				if DebugLevel > 1:
					print "DBG| <TAB> not specified, using %d char from #%d on" \
						% (LastTabSize, Tabs[-1])
				fill = LastTabSize - (pos - Tabs[-1]) % LastTabSize
			else:
				if DebugLevel > 1:
					print "DBG| <TAB> moved to %d" % Tabs[LastTab]
				fill = Tabs[LastTab] - pos
			# if...else
			if DebugLevel > 0:
				print "DBG| using %d filler characters" % fill
			
			if rfiller is None:
				s += (filler * (fill / len(filler)) + filler[:fill % len(filler)])
			else:
				s += (rfiller[len(rfiller) - fill % len(rfiller):]
					+ rfiller * (fill/len(rfiller)))
		# if we are on a tab
	# for
	return s
# ConvertLine()


def main(argv):
	
	Parser = optparse.OptionParser(usage=UsageMsg, version=Version,
		prog=os.path.basename(argv[0]), add_help_option=False)
	
	Parser.add_option("-d", "--debug", type="int", dest="Debug",
		default=0, help="sets the verbosity level [%default]")
	Parser.add_option("-n", "--maxlines", dest="MaxLines", type="int",
		default=None, help="maximum number of lines to be read [%default]")
	Parser.add_option("-s", "--skiplines", dest="SkipLines", type="int",
		default=None, help="number of lines to be skipped [%default]")
	Parser.add_option("-t", "--tab", dest="TabSpecs", action="append",
		default=[], help="add tab stops, comma separated [each 8 characters]")
	Parser.add_option("-f", "--filler", dest="Filler",
		default=' ', help="character to be used for filling tab space [%default]")
	Parser.add_option("-F", "--rfiller", dest="RightFiller",
		default=None, help="character to be used for right-filling tab space")
	Parser.add_option("-S", "--dontsort", dest="DontSort", action="store_true",
		default=False, help="don't sort tab stops (use at your risk!) [%default]")
	Parser.add_option("-h", "--help", dest="doHelp",
		action="store_true", default=False, help="prints this help message")
	
	(options, FileNames) = Parser.parse_args(argv[1:])
	DebugLevel = options.Debug
	
	if options.doHelp:
		Parser.print_help()
		sys.exit(0)
	
	if options.MaxLines is None: EndLine = None
	else: EndLine = options.MaxLines + options.SkipLines
	
	Tabs = []
	for TabSpec in options.TabSpecs:
		for spec in TabSpec.split(","):
			spec = spec.strip()
			if len(spec) == 0: continue
			rep = 1
			if spec[0] == '+' and len(Tabs) > 0:
				try: spec, rep = [ int(rse) for rse in spec[1:].split("*") ]
				except ValueError: spec = int(spec[1:])
				for i in xrange(rep):
					Tabs.append(Tabs[-1] + spec)
			else: Tabs.append(int(spec))
		# for spec
	# for TabSpec
	if not options.DontSort: Tabs.sort()
	if len(Tabs) == 0: Tabs = [8]
	if len(Tabs) < 2: LastTabSize = Tabs[0]
	else: LastTabSize = Tabs[-1] - Tabs[-2]
	
	if DebugLevel > 0:
		print "DBG| Tab spec: %r" % Tabs
		print "DBG| Last tab length: %r" % LastTabSize
	# if debug
	
	for iLine, line in enumerate(iter(fileinput.input(FileNames))):
		if iLine < options.SkipLines: continue
		if EndLine is not None and iLine >= EndLine: break
		
		print ConvertLine(line.strip(), Tabs, LastTabSize,
			filler=options.Filler, rfiller=options.RightFiller
			)
		
	# for input line
	
	return 0
# main()


if __name__ == "__main__": sys.exit(main(sys.argv))
