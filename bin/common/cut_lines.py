#!/usr/bin/env python

__version__ = "1.0"
__doc__ = """
Prints the specified lines of each file.
If a file is compressed by gzip or bzip2, it is uncompressed.
"""

import sys

try: import gz
except ImportError: pass
try: import bz2
except ImportError: pass
import collections


# ------------------------------------------------------------------------------
def OPEN(filename, mode = 'r'):
  """Opens a file, read-only (possibly a compressed one)"""
  if filename.endswith('.gz'):
    OpenProc = gzip.open
  elif filename.endswith('.bz2'):
    OpenProc = bz2.BZ2File.__call__
  else:
    OpenProc = open
  f = OpenProc(filename, mode)
  # GzipFile from Python 2.4 has no name attribute (it has "filename" though)
  if not hasattr(f, 'name'): f.name = filename
  return f
# OPEN()


# ------------------------------------------------------------------------------
def FileTail(
 data: "iterable data to select from",
 n: "number of lines to keep from the end",
 ) -> "data length and a buffer with at most n lines from the end of the file (not stripped)":
  
  sub = collections.deque([], n)
  l = 0
  for line in data:
    sub.append(line)
    l += 1
  return l, list(sub)
# FileTail()


def CutFileLines(
 data: "iterable data to select from",
 skipLines: "number of lines to skip" = 0,
 n: "number of lines to keep (None to keep all)" = None,
 ) -> "a buffer with at most n lines from startLine (not stripped)":
  
  dataiter = iter(data)
  
  for i in range(skipLines): next(dataiter)
  
  if n is None: return list(dataiter)
  else: return list(next(dataiter) for i in range(n))
  
# CutFileLines()


# ------------------------------------------------------------------------------
def cutLines(
 file_: "text file to read lines from",
 startline: "first line to keep (negative starts from the end)" = 1,
 lines: "number of lines to cut (negative goes backward from start, None: all)"
   = None,
 stopline: "line to stop at, included (negative starts from the end)" = None,
 ) -> "a buffer with the selected lines, not stripped":
  assert lines is None or stopline is None
  assert startline != 0 and stopline != 0
  
  #
  # a lot of juggling with the extremes; the goal is that:
  # 
  # startline  lines  stopline
  #  > 0        None   None     from startline to the end
  #  > 0        >= 0   None     from startline for lines
  #  > 0        < 0    None     from startline - lines for lines FIXME
  #  > 0        None   > 0      from startline for stopline - startline + 1
  #  > 0        None   < 0      from startline to -stopline lines from the end
  #  < 0        None   None     for |startlines| to the end
  #  < 0        >= 0   None     from |startlines| from the end, for lines
  #  < 0        < 0    None     from |startlines| - |lines| from the end, for |lines|
  #  < 0        None   > 0      from |startlines| from the end, to stopline
  #  < 0        None   < 0      from |startlines| from the end, for |stopline - startline|
  #
  #print("startline={} lines={} stopline={}".format(startline, lines, stopline))
  if stopline is not None:
    if (stopline >= 0) == (startline > 0):
      # the difference is the number of lines...
      if startline > 0: stopline += 1 # ... but include (positive) start line
      lines = max(stopline - startline, 0)
      stopline = None
    else:
      assert (stopline >= 0) != (startline > 0)
      assert lines is None
    # if ... else
  # if stop line
  
  if lines is not None and lines < 0:
    lines = -lines # for sanity
    if startline > 0:
      if startline < lines + 1:
        # we can't go that back from start line:
        # startline is kept (as stop value) and the number of lines is reduced
        lines = startline
        startline = 1
      else: startline -= lines
      assert startline > 0
    else:
      startline -= lines
  #
  
  assert startline != 0
  #print(" => startline={} lines={} stopline={}".format(startline, lines, stopline))
  
  # go for it!
  if startline < 0: # start keeping lines
    n, tail = FileTail(file_, n=-startline)
    if lines is not None: tail = tail[:lines]
    if stopline is not None: tail = tail[:stopline + 1 - (n + startline)]
    return tail
  else: # start skipping lines
    return CutFileLines(file_, skipLines=(startline - 1), n=lines)[:stopline]
  # if
  
# cutLines()


# ------------------------------------------------------------------------------
def cutLinesExec(args):
  
  import argparse
  
  Parser = argparse.ArgumentParser(description=__doc__)
  
  Parser.add_argument("InputFiles", nargs='*',
    help="files to extract lines from")
  
  Parser.add_argument("--verbose", "-v", action="store_true",
    help="prints a header line for each input file")
#  Parser.add_argument("--quiet", "-q", action="store_false", dest="verbose", 
#   help="doesn't print anything on the screen (useful, huh?)")
  Parser.add_argument("--startline", "-s", type=int, default=1,
    help="the number of starting line; negative means starting from the end"
    " (the last line is -1) [%(default)d]")
  Parser.add_argument("--stopline", "-S", type=int,
    help="the number of last line printed; overrides `--lines` option")
  Parser.add_argument("--lines", "-n", type=int,
    help="number of lines to be printed (if available); negative goes backward"
      " (default: print all)")
  Parser.add_argument("--stdin", "-c", action="store_true", dest="use_stdin",
    help="reads from standard input AFTER reading all input files")
  Parser.add_argument("--nouncompress", "-C", action="store_true",
    dest="DontUncompress",
    help="don't uncompress gzip and bzip2 files [%(default)s]"
    )
  
  Parser.add_argument("--unittest", "--test", action="store_true",
    help="run unit tests (ignoring all other options)"
    )
  
  Parser.add_argument('--version', action="version",
    version="%(prog)s version {}".format(__version__)
    )
  
  args = Parser.parse_args()
  
  if args.unittest:
    raise NotImplementedError \
      ("Internal error: test options should have been caught already!")
  #
  
  if args.startline == 0:
    raise RuntimeError("0 is not a valid start line number.")
  if args.stopline == 0:
    raise RuntimeError("0 is not a valid stop line number.")
  if args.stopline is not None and args.lines is not None:
    raise RuntimeError(
     "Options `--lines` (%d) and `--stopline` (%d) are exclusive"
     % (args.lines, args.stopline)
     )
  # if

  InputFiles = args.InputFiles[:]

  if len(InputFiles) == 0: args.use_stdin = True
  elif args.use_stdin is None: args.use_stdin = False
  
  if args.use_stdin: InputFiles.append(None)
  
  for FileName in InputFiles:
    if FileName is None: File = sys.stdin
    else:
      try:
        File = (open if args.DontUncompress else OPEN)(FileName, mode='r')
      except IOError:
        print("Can't open source file '%s'." % FileName, file=sys.stderr)
        raise
    
    Buffer = cutLines(File,
      startline=args.startline, lines=args.lines, stopline=args.stopline,
      )
    
    if args.verbose:
      print(80*"-", file=sys.stderr)
      print(
        "Standard input:" if FileName is None else ("File: '%s'" % FileName),
        file=sys.stderr, flush=True
        )
    
    # note that lines have not been stripped!
    for line in Buffer: print(line, end='')
    
    # close input file - if not stdin!
    if FileName is not None: File.close()
  # for FileName
  
  return 0
# cutLinesExec()


# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# ---  main dispatcher: run program or tests
# ------------------------------------------------------------------------------
if __name__ == '__main__':
  
  for testOption in ( '--test', '--unittest' ):
    if testOption not in sys.argv: continue
    sys.argv.remove(testOption)
    doTests = True
    break
  else: doTests = False

  # ----------------------------------------------------------------------------
  # ---  run program
  # ----------------------------------------------------------------------------
  if not doTests: sys.exit(cutLinesExec(sys.argv))
  
  # ----------------------------------------------------------------------------
  # ---  unit tests
  # ----------------------------------------------------------------------------

  import unittest

  # the definition of a unittest.TestCase derived class in a function
  # gets unnoticed
  class Tests(unittest.TestCase):
    
    TestDataLength = 10
    TestSettings = {
      # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      "full":
        {
          'args': {
            'startline': 1,    # > 0
            'lines':     None, # None
            'stopline':  None, # None
          },
          'res': {
            'start': 0,
            'stop':  TestDataLength,
          },
        }, # full
      # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      "from startline to the end":
        {
          'args': {
            'startline': 5,    # > 0
            'lines':     None, # None
            'stopline':  None, # None
          },
          'res': {
            'start': 4,
            'stop':  TestDataLength,
          },
        }, # from startline to the end
      # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      "from startline for lines":
        {
          'args': {
            'startline': 2,    # > 0
            'lines':     4,    # > 0
            'stopline':  None, # None
          },
          'res': {
            'start': 1,
            'stop':  5,
          },
        }, # from startline for lines
      # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      "from (startline - lines) for lines":
        {
          'args': {
            'startline': 5,    # > 0
            'lines':    -3,    # < 0
            'stopline':  None, # None
          },
          'res': {
            'start': 1,
            'stop':  4,
          },
        }, # from (startline - lines) for lines
      # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      "from (startline - lines) for lines (too short)":
        {
          'args': {
            'startline': 2,    # > 0
            'lines':    -3,    # < 0
            'stopline':  None, # None
          },
          'res': {
            'start': 0,
            'stop':  2,
          },
        }, # from (startline - lines) for lines (too short)
      # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      "from startline for (stopline - startline + 1)":
        {
          'args': {
            'startline': 2,    # > 0
            'lines':     None, # None
            'stopline':  5,    # > 0
          },
          'res': {
            'start': 1,
            'stop':  5,
          },
        }, # full
      # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      "from startline to (-stopline) lines from the end":
        {
          'args': {
            'startline': 3,    # > 0
            'lines':     None, # None
            'stopline':  -2,   # < 0
          },
          'res': {
            'start': 2,
            'stop':  TestDataLength - 2,
          },
        }, # from startline to (-stopline) lines from the end
      # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      "for |startlines| to the end":
        {
          'args': {
            'startline': -6,   # < 0
            'lines':     None, # None
            'stopline':  None, # None
          },
          'res': {
            'start': TestDataLength - 6,
            'stop':  TestDataLength,
          },
        }, # for |startlines| to the end
      # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      "from |startlines| from the end, for lines":
        {
          'args': {
            'startline': -6,   # < 0
            'lines':      3,   # >= 0
            'stopline':  None, # None
          },
          'res': {
            'start': TestDataLength - 6,
            'stop':  7,
          },
        }, # from |startlines| from the end, for lines
      # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      "from |startlines|-|lines| from the end, for |lines|":
        {
          'args': {
            'startline': -4,   # < 0
            'lines':     -3,   # < 0
            'stopline':  None, # None
          },
          'res': {
            'start': TestDataLength - 7,
            'stop':  TestDataLength - 4,
          },
        }, # from |startlines|-|lines| from the end, for |lines|
      # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        #  < 0       None   > 0      from |startlines| from the end, to stopline
      "from |startlines| from the end, to stopline":
        {
          'args': {
            'startline': -6,   # < 0
            'lines':     None, # None
            'stopline':  8,    # > 0
          },
          'res': {
            'start': TestDataLength - 6,
            'stop':  9,
          },
        }, # from |startlines| from the end, to stopline
      # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        #  < 0       None   < 0      from |startlines| from the end for |stopline-startline|
      "from |startlines| from the end for |stopline-startline|":
        {
          'args': {
            'startline': -6,    # < 0
            'lines':     None, # None
            'stopline':  -3, # < 0
          },
          'res': {
            'start': TestDataLength - 6,
            'stop':  TestDataLength - 3,
          },
        }, # from |startlines| from the end for |stopline-startline|
      # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    
    } # TestSettings
    
    def _testData(self): return list(range(Tests.TestDataLength))
    
    def _runTest(self, params):
      
      data = self._testData()
      expected = data[params['res']['start']:params['res']['stop']]
      selected = cutLines(data, **(params['args']))
      # self.assertEqual(len(selected), len(expected))
      self.assertEqual(selected, expected)
      
    # runTest()
    
    def tests(self):
      for key, params in Tests.TestSettings.items():
        with self.subTest(key, params=params['args'], exp=params['res']):
          self._runTest(params)
      # for
    # tests()
    
  # class Tests

  assert len(Tests.TestSettings) == 12;
  unittest.main()

# main
