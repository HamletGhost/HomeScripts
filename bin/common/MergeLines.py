#!/usr/bin/env python
#
# Merges lines of a stream according to some pattern.
# 
# This program is designed to allow very complex operations.
# Each operation is in turn consulted about the input lines that the program
# gets and when one operation decides it is ready it will print its result and
# return the unprocessed lines so that they can be delivered to the other
# operations.
#

import sys
import os
import optparse

DebugLevel = 0
Version = "%prog v. 1.0"
UsageMsg = """%prog  mergespec [mergespec]

Merges lines from a stream, to standard output.
Each specification describes on how many lines to operate and the actions to be
taken. The specification can be in two forms:
- simple: "N[@sep]" merges N lines using specified string as separator; the
   separator is a single space by default (you can also specify an empty one);
   if N is negative, that amount of lines is skipped (you may need to use '--')
- full: a python dictionary with the following fields:
* 'N': as in the simple version, the number of lines on wich to operate
* 'sep': a string or list of strings, used as separators
The full specification can be used to describe any kind of supported operations,
while the simple one supports only to so far. To get more information about the
supported operations, use the respective command line options.

Simple example:

%prog 3 2@" | "

will merge three lines with a space, then two lines with a " | " in between them
then again other three lines, and so on cyclically.
"""

### information output #########################################################
def StdErr(msg):
	if sys.stdout.softspace: print >>sys.stdout
	print >>sys.stderr, msg
# StdErr()

def Error(msg): return StdErr(msg)
def Debug(msg, level = None):
	if level is None or level <= DebugLevel: StdErr("DBG| " + msg)

### auxiliary classes ##########################################################
class Break(Exception): pass

class CyclicIterator(object):
	def __init__(self, iterable):
		self.iterable = iterable
		self.reset()
	# __init__()
	
	def reset(self): self.baseiter = iter(self.iterable)
	def __iter__(self): return self
	def next(self):
		try:
			return self.baseiter.next()
		except StopIteration:
			self.reset()
			return self.baseiter.next()
	# next()
# CyclicList()


class SpecRef:
	def __init__(self, source, startline = 0):
		self.source = source
		self.startline = startline
	# __init__()
	
	def __str__(self): return self.Str(absline=0)
	def Str(self, absline = 0):
		return "%r@%d" % (self.source, absline - self.startline)
# class SpecRef


### operator classes ###########################################################
class Operation(object):
	"""Operation base object.
	
	This object defines the protocol for an operation class.
	The operation will be initialized by a specification parameters, usually a
	dictionary. A (shallow) copy is kept in the 'params' attribute by default.
	If the parameter is a dictionary and it contains the key 'type', a warning
	is printed if that type is not equal to the name of this class.
	
	Each objects holds a buffer of lines (the operands). The operation Operate()s
	on a line at a time. For each line, the operation can detect one of the
	following states:
	1) the line is suitable for being processed, and this processing concludes
	  the operation itself: Operate() adds the line to the buffer, gets ready to
	  print a result from the buffered and return False, meaning that it does not
	  need any more data to operate
	2) the line is suitable for being processed, but it does not conclude the
	  operation (or it is not sure if it does): the line is buffered in the
	  object, True is returned meaningthat there could be more data needed.
	3) the line is not suitable for being processed: as (1)
	
	PrintResult() attribute is expected to print the result only if it is ready
	and final; in that case, the lines used are removed from the operands buffer
	and the resulting buffer is returned. Otherwise, None is returned.
	PrintPartialResult() is expected to print a result even if it's
	not complete.
	
	Buffered() returns the lines that are still unprocessed.
	
	Reset() resets the internal status of the object, but does not affect the
	buffered operands; Flush() instead forgets the buffered operands (and it
	should reset the operation to a valid state), but it returns them.
	
	"""
	def __init__(self, spec):
		"""Default constructor, saves the parameters."""
		self.params = spec
		self.Operands = []
		if isinstance(spec, dict) and spec.has_key('type') \
		  and spec['type'] != self.__class__.__name__:
			Warning(
			  "Warning: building a '%s' operator from a specification of type '%s'"
			  % (self.__class__.__name__, spec['type']))
		# type check
	# __init__()
	
	def Reset(self): pass
	def Flush(self, nLines = None):
		Debug("Flushing (buffer has %d operands)" % len(self.Operands), level=4)
		Operands = self.Operands
		if nLines is None: self.Operands = []
		else:              del self.Operands[0:nLines]
		self.Reset()
		return Operands
	# Flush()
	def Operate(self, line):
		"""Returns True if it needs more data to operate."""
		self.Operands.append(line)
		return False
	# Operate()
	def PrintResult(self, stream = sys.stdout): self.Operands  = []
	def PrintPartialResult(self, stream = sys.stdout): pass
	def Buffered(self): return self.Operands
	
	RegisteredOperations = set()
	@staticmethod
	def CreateOperation(spec):
		for OperationClass in Operation.RegisteredOperations:
			if not hasattr(OperationClass, 'isSpecCompatible'): continue
			if OperationClass.isSpecCompatible(spec):
				return OperationClass(spec)
		else: return None
	# CreateOperation()
	
	@staticmethod
	def RegisterOperation(OperationClass):
		Operation.RegisteredOperations.add(OperationClass)
	
	@staticmethod
	def isSpecCompatible(spec): return False
	
	@staticmethod
	def Brief():
		return """Base operator, accepts everything, does nothing."""
	@staticmethod
	def Desc():
		return \
		  """Base operator, accepts everything, does nothing. Don't use this!"""
	# Desc()
	
# class Operation


### OpMergeLines ###
class OpMergeLines(Operation):
	@staticmethod
	def Brief():
		return """Merges the next N lines with specified separators."""
	@staticmethod
	def Desc():
		return OpMergeLines.Brief() + """
		The specification includes two fields:
		'N' (integral, mandatory, positive): number of lines to be merged
		'sep' (string or list of strings): separators used
		
		The operator merges together N lines, using the first separator in the
		'sep' list between the first and the second line, the second separator
		before the third line and so on. If there are more lines than separators,
		the separators are run cyclically. By default, there is just one separator
		made of a space character (' ').
		"""
	# Desc()
	
	def __init__(self, spec):
		Operation.__init__(self, spec)
		self.params.setdefault('sep', [ ' ', ])
		self.Reset()
	
	def __str__(self):
		return "< N: %d, sep: %r >" % (self.params['N'], self.params['sep'])
	
	@staticmethod
	def isSpecCompatible(spec):
		return \
		  spec.has_key('N') and isinstance(spec['N'], int) and spec['N'] >= 0
	# isSpecCompatible()
	
	def Reset(self):
		self.LinesLeft = self.params['N']
		self.result = ""
		if isinstance(self.params['sep'], basestring):
			self.SepIter = CyclicIterator([ self.params['sep'], ])
		else:
			self.SepIter = CyclicIterator(self.params['sep'])
		Debug("Reset: %d lines left, separators: %r"
		  % (self.LinesLeft, self.params['sep']), level=3)
	# Reset()
	
	def Operate(self, line):
		Debug("Lines left: %d/%d" % (self.LinesLeft, self.params['N']), level=3)
		if self.LinesLeft <= 0: return False
		if self.LinesLeft != self.params['N']:
			sep = self.SepIter.next()
			Debug(" - using separator: '%s'" % sep, level=2)
			self.result += sep
		self.result += line
		self.LinesLeft -= 1
		return True
	# Operate()
	
	def PrintResult(self, stream = sys.stdout):
		if self.LinesLeft > 0: return None
		self.PrintPartialResult(stream)
		self.Flush(self.params['N'])
		return self.Buffered()
	# PrintResult()
	
	def PrintPartialResult(self, stream = sys.stdout):
		if stream: print >>stream, self.result
	
# class OpMergeLines
Operation.RegisterOperation(OpMergeLines)


### OpSkipLines ###
class OpSkipLines(Operation):
	@staticmethod
	def Brief():
		return """Skips the next N lines."""
	@staticmethod
	def Desc():
		return OpMergeLines.Brief() + """
		The specification includes one field:
		'N' (integral, mandatory, positive): number of lines to be skipped
		
		The operator steals from the input N lines, which are not printed out.
		"""
	# Desc()
	
	def __init__(self, spec):
		Operation.__init__(self, spec)
		self.Reset()
	# __init__()
	
	def __str__(self):
		return "< N: %d >" % (self.params['N'])
	
	@staticmethod
	def isSpecCompatible(spec):
		return \
		  spec.has_key('N') and isinstance(spec['N'], int) and spec['N'] >= 0 \
		  and len(spec) == 1
	# isSpecCompatible()
	
	def Reset(self):
		self.LinesLeft = self.params['N']
		self.result = ""
		Debug("Reset: %d lines left" % (self.LinesLeft, ), level=3)
	# Reset()
	
	def Operate(self, line):
		Debug("Lines left: %d/%d" % (self.LinesLeft, self.params['N']), level=3)
		if self.LinesLeft <= 0: return False
		self.LinesLeft -= 1
		return True
	# Operate()
	
	def PrintResult(self, stream = sys.stdout):
		if self.LinesLeft > 0: return None
		self.PrintPartialResult(stream)
		self.Flush(self.params['N'])
		return self.Buffered()
	# PrintResult()
	
	def PrintPartialResult(self, stream = sys.stdout): return
	
# class OpSkipLines
Operation.RegisterOperation(OpSkipLines)


### main program ###############################################################
def main(argv):
	global DebugLevel # why is this needed? mystery
	
	Parser = optparse.OptionParser \
	  (usage=UsageMsg, version=Version, prog=os.path.basename(argv[0]))
	
#	Parser.set_defaults(Option=None)
	
	# input options
	Parser.add_option("-o", "--output", dest="OutputFile", default=None,
	  help="output file (empty for none) [standard output]")
	# operating mode options
	Parser.add_option("-d", "--debug", dest="Debug", type="int", default=0,
	  help="verbosity of debugging messages (0: no debug message) [%default]")
	Parser.add_option("-l", "--listops", dest="DoListOperations", default=False,
	  action="store_true", help="print the list of operators and exits")
	Parser.add_option("-L", "--descop", dest="DoDescribeOperations", default=[],
	  action="append", help="print the description for this operator(s)")
	
	(options, Specs) = Parser.parse_args(argv[1:])
	
	DebugLevel = options.Debug
	Debug("Command line:\n'%s'" % "' '".join(argv), level=1)
	Debug("Verbosity level: %d" % DebugLevel, level=1)
	
	OperationsDictionary = dict( [ (OperationClass.__name__, OperationClass )
	  for OperationClass in Operation.RegisteredOperations ])
	
	if options.DoListOperations:
		print "%s operation classes are available:" \
		  % len(Operation.RegisteredOperations)
		for OperationClass in Operation.RegisteredOperations:
			print "%r\n\t%s" % (OperationClass.__name__, OperationClass.Brief())
		return 0
	# if list operators
	
	if len(options.DoDescribeOperations):
		for OperationClassName in options.DoDescribeOperations:
			try:
				OperationClass = OperationsDictionary[OperationClassName]
				print "%r\n\t%s" % (OperationClass.__name__, OperationClass.Desc())
			except KeyError:
				print "Operation '%s' not supported" % OperationClassName
		return 0
	# if list operators
	
	setattr(options, 'InputFile', '')
	setattr(options, 'ChunkSize ', 1)
	
	SpecFiles = [ SpecRef('command line', 0), ]
	iSpec = 0
	Operations = []
	while iSpec < len(Specs):
		NewSpec = None
		try:
			ospec = Specs[iSpec]
			spec = ospec.strip()
			
			if len(spec) == 0: raise Break # empty line
			
			if spec[0] == "#": raise Break # comment
			
			if spec[0] == "@":
				SpecSource = spec[1:]
				if len(SpecSource) == 0: # some kind of marker
					SpecFiles.pop()
					raise Break
				try:
					NewSpecs = open(SpecSource, 'r').readlines()
				except IOError:
					Error("Can't open spec file '%s'" % SpecSource)
				Specs[iSpec:iSpec] = NewSpecs # inserting the new lines in place
				Specs.append("@") # end of file marker
				SpecFiles.append(SpecRef(SpecSource, iSpec))
				raise Break
			
			if spec[0] == "{":
				try:
					NewSpec = eval(spec)
				except BaseException, e:
					Error("Error (%r) in specification %s '%s'"
					  % (e, SpecFiles[-1].Str(iSpec), spec))
				raise Break
				if not isinstance(NewSpec, dict):
					Error("Error in specification %s '%s' (it's %r, not dictionary)"
					  % (SpecFiles[-1].Str(iSpec), spec, type(NewSpec).__name__))
			
			# simple spec
			tokens = ospec.split('@', 1)
			NewSpec = {}
			try:
				NewSpec['N'] = int(tokens[0])
			except IndexError:
				Error("Invalid specification '%s' in spec %s"
				  % (ospec, SpecFiles[-1].Str(iSpec)))
				continue
			except ValueError:
				Error("Invalid number of lines ('%s') in spec %s"
				  % (tokens[0], SpecFiles[-1].Str(iSpec)))
				continue
			if len(tokens) == 2:
				sep = tokens[1]
				name = OpMergeLines.__name__
			else:
				sep = ' '
				if NewSpec['N'] < 0: 
					name = OpSkipLines.__name__
					NewSpec['N'] = -NewSpec['N']
				else:
					name = OpMergeLines.__name__
			
			NewSpec.update({ 'sep': sep, 'type': name })
		except Break: pass
		iSpec += 1
		
		if NewSpec is None: continue
		
		if NewSpec['N'] <= 0:
			Error("Warning: empty spec %r (from %s)"
			  % (NewSpec, SpecFiles[-1].Str(iSpec)))
			continue
		try:
			NewOperation = OperationsDictionary[NewSpec['type']](NewSpec)
		except KeyError:
			NewOperation = Operation.CreateOperation(NewSpec)
		if NewOperation is None:
			Error("Operation not recognized (specification: %r)" % spec)
			continue
		Operations.append(NewOperation)
		
		Debug("Added operation #%d=%s" % (len(Operations)-1, Operations[-1]),
		  level=2)
	# while parsing specs
	
	
	if DebugLevel >= 1:
		Debug("%d operations:" % len(Operations))
		for opdata in enumerate(Operations): Debug("OP#%d: %r" % opdata)
	
	if options.InputFile: InputFile = open(options.InputFile, 'r')
	else:                 InputFile = sys.stdin
	
	if options.OutputFile is not None:
		if len(options.OutputFile) > 0: OutputFile = open(options.OutputFile, 'w')
		else:                           OutputFile = None
	else:                              OutputFile = sys.stdout
	
#	ChunkSize = options.ChunkSize
	ChunkSize = 1
	
	OperIter = CyclicIterator(Operations)
	nOperations = len(Operations)
	CurrentOperation = OperIter.next()
	InputBuffer = []
	iLine = 0
	iBufLine = 0
	while True: # main loop
		# fill the input buffer
		if len(InputBuffer) == 0:
			for i in xrange(ChunkSize):
				NewLine = InputFile.readline()
				if len(NewLine) == 0: break # end of file!
				InputBuffer.append(NewLine.rstrip('\n'))
			# for
		if len(InputBuffer) == 0: break # end of file! end of processing! end!!!
		
		line = InputBuffer.pop(0)
		Debug("Operating on line %r" % line, level=2)
		# find the first operator willing to use this line
		for iOper in xrange(nOperations):
			Debug("- trying next operator (%d)" % (iOper+1), level=2)
			# the operation will return True if it thinks it could need more input;
			# in that case, provide more input by another iteration of main loop;
			if CurrentOperation.Operate(line):
				Debug("  operator (%d) accepted the line" % iOper, level=3)
				break
			# the operation thinks it's enough data to make a decision; then:
			# - print the result, if any
			UnprocessedInput = CurrentOperation.PrintResult(OutputFile)
			# - add back the unused lines, if any
			if UnprocessedInput is not None: # this means the operator operated!
				Debug("Adding back %d unprocessed lines:\n%s" % (
				  len(UnprocessedInput),
				  "\n".join([ repr(ui) for ui in UnprocessedInput ])
				  ), level=4)
				InputBuffer[0:0] = UnprocessedInput
			# if unprocessed lines are present
			
			CurrentOperation = OperIter.next()
		else:
			break # no operation available for this line??
	# while main loop
	if CurrentOperation is not None:
		CurrentOperation.PrintPartialResult(OutputFile)
	
	return 0
# main()


if __name__ == "__main__": sys.exit(main(sys.argv))