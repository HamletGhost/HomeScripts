#!/usr/bin/env python

import sys
import optparse

Version = "%prog 0.1"
UsageMsg = """
Prints the specified lines of each file.

Usage:  %prog [options] [InputFile] [InputFile] ...
"""


if __name__ == '__main__':
	
	Parser = optparse.OptionParser(usage=UsageMsg,
		version=Version, add_help_option=False)
	
	Parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
		default=False, help="prints a header line for each input file")
#	Parser.add_option("-q", "--quiet", action="store_false", dest="verbose", 
#		help="doesn't print anything on the screen (useful, huh?)")
	Parser.add_option("-s", "--startline", dest="startline", type="int",
		default=0,
		help="the number of starting line; negative means starting from the end"
		" (the last line is -1) [%default]")
	Parser.add_option("-n", "--lines", dest="lines", type="int",
		default=1,
		help="number of lines to be printed (if available); negative means all"
			" left ones [%default]")
	Parser.add_option("-c", "--stdin", action="store_true", dest="use_stdin",
		help="reads fron standard input AFTER reading all input files")
	Parser.add_option("-h", "--help", dest="doHelp",
		action="store_true", default=False, help="prints this help message")
	
	(options, FileNames) = Parser.parse_args()
	
	if options.doHelp:
		Parser.print_help()
		sys.exit(0)
	
	# check option values
#	if options.lines <= 0:
#		Parser.error(
#			"--lines options requires a positive number of lines, not '%d'"
#			% options.lines)
		
	
	if len(FileNames) == 0: options.use_stdin = True
	elif options.use_stdin is None: options.use_stdin = False
	
	if options.use_stdin: FileNames.append(None)
	
	for FileName in FileNames:
		if FileName is None: file = sys.stdin
		else:
			try:
				file = open(FileName, "r")
			except IOError:
				print >>sys.stderr, "Can't open source file '%s'." % FileName
				raise
		
		Buffer = []
		# go for it!
		if options.startline < 0: # start keeping lines
			BufLen = -options.startline
			for line in file:
				Buffer.append(line)
				while len(Buffer) > BufLen: del Buffer[0]
			# for
			# we don't really need the following lines:
			if options.lines >= 0: del Buffer[options.lines:]
		else: # start skipping lines
			BufLen = options.lines
			if options.startline > 1:
				nLeft = options.startline - 1
				for line in file:
					nLeft -= 1
					if nLeft <= 0: break
			for line in file:
				if BufLen >= 0 and len(Buffer) >= BufLen: break
				Buffer.append(line)
			# for
		# if
		
		if options.verbose:
			print >>sys.stderr, 80*"-"
			if FileName is None: print >>sys.stderr, "Standard input:"
			else: print >>sys.stderr, "File: '%s'" % FileName
		
		# note that lines have not been stripped!
		for line in Buffer: print line,
		
		# close input file - if not stdin!
		if FileName is not None: file.close()
	# for FileName
	
	
	sys.exit(0)
# main
