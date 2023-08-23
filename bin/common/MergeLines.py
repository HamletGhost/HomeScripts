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

__version__ = "v. 2.0"
__doc__ = r"""Merges lines from a stream, to standard output.

Each specification describes on how many lines to operate and the actions to be
taken. The specification can be in two forms.
A simple specification, `N[@sep]`, merges N lines using specified string as
separator; the separator is a single space by default (you can also specify an
empty one); if N is negative, that amount of lines is skipped (you may need to
use '--').
A full specification is a python dictionary with the following fields:
`N`, as in the simple version, the number of lines on wich to operate;
`sep`, a string or list of strings, used as separators.
The full specification can be used to describe any kind of supported operations,
while the simple one supports only two so far. To get more information about the
supported operations, use the respective command line options.

Simple example:

%(prog)s 3 2@" | "

will merge three lines with a space, then two lines with a " | " in between them
then again other three lines, and so on cyclically.
"""
DebugLevel = 0

import sys
import logging


### information output #########################################################
def StdErr(*msg):
  logging.error(*msg)
# StdErr()

def Error(*msg): return StdErr(*msg)
def Warning(*msg): return logging.warning(*msg)
def Debug(*msg, level = None):
  if msg and level is None or level <= DebugLevel:
    logging.debug("DBG| " + msg[0], *msg[1:])

### auxiliary classes ##########################################################
class Break(Exception): pass

class CyclicIterator:
  def __init__(self, iterable):
    self.iterable = iterable
    self.reset()
  # __init__()
  
  def reset(self): self.baseiter = iter(self.iterable)
  def __iter__(self): return self
  def __next__(self):
    try:
      return next(self.baseiter)
    except StopIteration:
      self.reset()
      return next(self.baseiter)
  # next()
# CyclicIterator()


class SpecRef:
  def __init__(self, source, startline = 0):
    self.source = source
    self.startline = startline
  # __init__()
  
  def __str__(self): return self.Str(absline=0)
  def Str(self, absline = 0):
    return f"{self.source:r}@{absline - self.startline:d}"
# class SpecRef


### operator classes ###########################################################
class Operation:
  """Operation base object.
  
  This object defines the protocol for an operation class.
  The operation will be initialized by a specification parameters, usually a
  dictionary. A (shallow) copy is kept in the 'params' attribute by default.
  If the parameter is a dictionary and it contains the key 'type', a warning
  is printed if that type is not equal to the name of this class.
  
  Each objects holds a buffer of lines (the operands). The operation
  CollectData()s on a line at a time. For each line, the operation can detect
  one of the following states:
  1) the line is suitable for being processed, and this processing concludes
    the operation itself: CollectData() adds the line to the buffer, gets ready
    to print a result from the buffered and returns `Operation.EnoughData`,
    meaning that it does not need any more data to operate
  2) the line is suitable for being processed, but it does not conclude the
    operation (or it is not sure if it does): the line is buffered in the
    object, `Operation.NeedMore` is returned meaning that there could be more
    data needed.
  3) the line is not suitable for being processed: `Operation.NotForMe` is
    returned.
  
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
  EnoughData = 0 # used by CollectData() to declare there is enough input
  NeedMore = 1   # used by CollectData() to declare the need for more input
  NotForMe = 2   # used by CollectData() to declare it won't process this data
  
  def __init__(self, spec):
    """Default constructor, saves the parameters."""
    self.params = spec
    self.Operands = []
    if isinstance(spec, dict) and 'type' in spec \
      and spec['type'] != self.__class__.__name__:
      Warning(
        "Warning: building a '%s' operator from a specification of type '%s'",
        self.__class__.__name__, spec['type'])
    # type check
  # __init__()
  
  def Reset(self): pass
  def Flush(self, nLines = None):
    Debug("Flushing (buffer has %d operands)", len(self.Operands), level=4)
    Operands = self.Operands
    del self.Operands[0:nLines]
    self.Reset()
    return Operands
  # Flush()
  def CollectData(self, line):
    self.Operands.append(line)
    return Operation.EnoughData
  # CollectData()
  def PrintResult(self, stream = sys.stdout): self.Operands = []
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
    return 'N' in spec and isinstance(spec['N'], int) and spec['N'] >= 0
  # isSpecCompatible()
  
  def Reset(self):
    self.LinesLeft = self.params['N']
    self.result = ""
    if isinstance(self.params['sep'], str):
      self.SepIter = CyclicIterator([ self.params['sep'], ])
    else:
      self.SepIter = CyclicIterator(self.params['sep'])
    Debug("Reset: %d lines left, separators: %r",
      self.LinesLeft, self.params['sep'], level=3)
  # Reset()
  
  def CollectData(self, line):
    """Swallows every line."""
    if self.LinesLeft <= 0: return Operation.EnoughData
    if self.LinesLeft != self.params['N']:
      sep = next(self.SepIter)
      Debug(" - using separator: '%s'", sep, level=2)
      self.result += sep
    self.result += line
    self.LinesLeft -= 1
    Debug("Lines to go: %d/%d", self.LinesLeft, self.params['N'], level=3)
    return Operation.EnoughData if self.LinesLeft <= 0 else Operation.NeedMore
  # CollectData()
  
  def PrintResult(self, stream = sys.stdout):
    if self.LinesLeft > 0: return None
    self.PrintPartialResult(stream)
    self.Flush(self.params['N'])
    return self.Buffered()
  # PrintResult()
  
  def PrintPartialResult(self, stream = sys.stdout):
    if stream: print(self.result, file=stream)
  
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
    return f"< N: {self.params['N']} >"
  
  @staticmethod
  def isSpecCompatible(spec):
    return 'N' in spec and isinstance(spec['N'], int) and spec['N'] >= 0 \
      and len(spec) == 1
  # isSpecCompatible()
  
  def Reset(self):
    self.LinesLeft = self.params['N']
    self.result = ""
    Debug("Reset: %d lines left", self.LinesLeft, level=3)
  # Reset()
  
  def CollectData(self, line):
    """Swallows every line."""
    Debug("Lines left: %d/%d", self.LinesLeft, self.params['N'], level=3)
    if self.LinesLeft <= 0: return Operation.EnoughData
    self.LinesLeft -= 1
    return Operation.NeedMore
  # CollectData()
  
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
def main():
  import argparse
  import textwrap
  import shutil
  
  global DebugLevel
  
  logging.basicConfig(level=logging.DEBUG if DebugLevel else logging.INFO)
  
  parser = argparse.ArgumentParser(
    description="\n".join(textwrap.wrap(
      __doc__,
      width=shutil.get_terminal_size((80, 20)).columns,
      expand_tabs=True,
      replace_whitespace=False,
      break_long_words=True,
      drop_whitespace=False,
      break_on_hyphens=True,
      tabsize=8,
      )),
    formatter_class=argparse.RawDescriptionHelpFormatter,
    )
  
#	parser.set_defaults(Option=None)
  
  # input options
  parser.add_argument('specs', nargs="*", help='input specifications')
  parser.add_argument("-o", "--output", default=None,
    help="output file (empty for none) [standard output]")
  # operating mode options
  parser.add_argument("-d", "--debug", type=int, default=0,
    help="verbosity of debugging messages (0: no debug message) [%(default)d]")
  parser.add_argument("-l", "--listops", default=False,
    action="store_true", help="print the list of operators and exits")
  parser.add_argument("-L", "--descop", default=[],
    action="append", help="print the description for this operator(s)")
  parser.add_argument \
    ('--version', '-V', action='version', version='%(prog)s ' + __version__)
  
  args = parser.parse_args()
  
  DebugLevel = args.debug
  if args.debug > 0:
    logging.getLogger().setLevel(logging.DEBUG)
  Debug("Command line:\n'%s'", "' '".join(sys.argv), level=1)
  Debug("Verbosity level: %d", DebugLevel, level=1)
  
  OperationsDictionary = dict((OperationClass.__name__, OperationClass )
    for OperationClass in Operation.RegisteredOperations)
  
  if args.listops:
    print(f"{len(Operation.RegisteredOperations)} operation classes are available:")
    for OperationClass in Operation.RegisteredOperations:
      print(f"'{OperationClass.__name__}'\n\t{OperationClass.Brief()}")
    return 0
  # if list operators
  
  if args.descop:
    for OperationClassName in args.descop:
      try:
        OperationClass = OperationsDictionary[OperationClassName]
        print(f"'{OperationClass.__name__}'\n\t{OperationClass.Desc()}")
      except KeyError:
        print(f"Operation '{OperationClassName}' not supported")
    return 0
  # if list operators
  
  setattr(args, 'InputFile', '')
  setattr(args, 'ChunkSize', 1)
  
  Specs = args.specs[:]
  SpecFiles = [ SpecRef('command line', 0), ]
  iSpec = 0
  Operations = []
  while iSpec < len(args.specs):
    NewSpec = None
    try:
      ospec = Specs[iSpec]
      spec = ospec.strip()
      
      if not spec: raise Break # empty line
      
      if spec[0] == "#": raise Break # comment
      
      if spec[0] == "@":
        SpecSource = spec[1:]
        if len(SpecSource) == 0: # some kind of marker
          SpecFiles.pop()
          raise Break
        try:
          NewSpecs = open(SpecSource, 'r').readlines()
        except IOError:
          Error("Can't open spec file '%s'", SpecSource)
        Specs[iSpec:iSpec] = NewSpecs # inserting the new lines in place
        Specs.append("@") # end of file marker
        SpecFiles.append(SpecRef(SpecSource, iSpec))
        raise Break
      
      if spec[0] == "{":
        try:
          NewSpec = eval(spec)
        except Exception as e:
          Error("Error (%r) in specification %s '%s'",
            e, SpecFiles[-1].Str(iSpec), spec)
        raise Break
        if not isinstance(NewSpec, dict):
          Error("Error in specification %s '%s' (it's %r, not dictionary)",
            SpecFiles[-1].Str(iSpec), spec, type(NewSpec).__name__)
      
      # simple spec
      tokens = ospec.split('@', 1)
      NewSpec = {}
      try:
        NewSpec['N'] = int(tokens[0])
      except IndexError:
        Error("Invalid specification '%s' in spec %s",
          ospec, SpecFiles[-1].Str(iSpec))
        continue
      except ValueError:
        Error("Invalid number of lines ('%s') in spec %s",
          tokens[0], SpecFiles[-1].Str(iSpec))
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
      Error("Warning: empty spec %r (from %s)",
        NewSpec, SpecFiles[-1].Str(iSpec))
      continue
    try:
      NewOperation = OperationsDictionary[NewSpec['type']](NewSpec)
    except KeyError:
      NewOperation = Operation.CreateOperation(NewSpec)
    if NewOperation is None:
      Error("Operation not recognized (specification: %r)", spec)
      continue
    Operations.append(NewOperation)
    
    Debug("Added operation #%d=%s", len(Operations)-1, Operations[-1],
      level=2)
  # while parsing specs
  
  
  if DebugLevel >= 1:
    Debug("%d operations:", len(Operations))
    for opdata in enumerate(Operations): Debug("OP#%d: %s" % opdata)
  
  InputFile = open(args.InputFile, 'r') if args.InputFile else sys.stdin
  
  OutputFile = sys.stdout if args.output is None else \
    open(args.output, 'w') if args.output else None
  
  ChunkSize = args.ChunkSize
  
  OperIter = CyclicIterator(Operations)
  nOperations = len(Operations)
  CurrentOperation = next(OperIter)
  Debug("Starting with operation %s", CurrentOperation, level=2)
  InputBuffer = []
  iLine = 0
  iBufLine = 0
  while True: # main loop
    # fill the input buffer
    if not InputBuffer:
      for i in range(ChunkSize):
        NewLine = InputFile.readline()
        if not NewLine:
          Debug("End of input file.", level=2)
          break # end of file!
        InputBuffer.append(NewLine.rstrip('\n'))
      # for
    if not InputBuffer: break # end of file! end of processing! end!!!
    
    line = InputBuffer.pop(0)
    Debug("Operating on line %r", line, level=2)
    # find the first operator willing to use this line
    for iOper in range(nOperations):
      # the operation will return True if it thinks it could need more input;
      # in that case, provide more input by another iteration of main loop;
      res = CurrentOperation.CollectData(line)
      if res == Operation.NeedMore:
        Debug("  operator swallowed the line", level=3)
        break
      elif res == Operation.EnoughData:
        Debug("  operator swallowed the line and is ready", level=3)
        # the operation thinks it's enough data to make a decision; then:
        # - print the result, if any
        UnprocessedInput = CurrentOperation.PrintResult(OutputFile)
        # - add back the unused lines, if any
        if UnprocessedInput: # this means the operator operated!
          Debug("Adding back %d unprocessed lines:\n%s",
            len(UnprocessedInput), "\n".join(map(repr, UnprocessedInput)),
            level=4)
          InputBuffer[0:0] = UnprocessedInput
        # if unprocessed lines are present
      # if ... else
      
      # whether the selected operation had enough data or declined to operate,
      # we skip to the next one
      Debug("- trying next operator (%d)", (iOper+1), level=2)
      CurrentOperation = next(OperIter)
    else:
      break # no operation available for this line??
  # while main loop
  if CurrentOperation is not None:
    CurrentOperation.PrintPartialResult(OutputFile)
  
  return 0
# main()


if __name__ == "__main__": sys.exit(main())
