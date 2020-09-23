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



if __name__ == '__main__':
  
  import argparse
  
  Parser = argparse.ArgumentParser(description=__doc__)
  
  Parser.add_argument("InputFiles", nargs='*',
    help="files to extract lines from")
  
  Parser.add_argument("--verbose", "-v", action="store_true",
    help="prints a header line for each input file")
#  Parser.add_argument("--quiet", "-q", action="store_false", dest="verbose", 
#   help="doesn't print anything on the screen (useful, huh?)")
  Parser.add_argument("--startline", "-s", type=int, default=0,
    help="the number of starting line; negative means starting from the end"
    " (the last line is -1) [%(default)d]")
  Parser.add_argument("--lines", "-n", type=int, default=1,
    help="number of lines to be printed (if available); negative means all"
      " left ones [%(default)d]")
  Parser.add_argument("--stdin", "-c", action="store_true", dest="use_stdin",
    help="reads from standard input AFTER reading all input files")
  Parser.add_argument("--nouncompress", "-C", action="store_true",
    dest="DontUncompress",
    help="don't uncompress gzip and bzip2 files [%(default)s]"
    )
  
  Parser.add_argument('--version', action="version",
    version="%(prog)s version {}".format(__version__)
    )
  
  args = Parser.parse_args()

  # check option values
#  if args.lines <= 0:
#     Parser.error(
#      "--lines options requires a positive number of lines, not '%d'"
#      % args.lines)
  
  if args.stopline is not None:
    args.lines = max(args.stopline - args.startline, 0)
  
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
    
    Buffer = []
    # go for it!
    if args.startline < 0: # start keeping lines
      BufLen = -args.startline
      for line in File:
        Buffer.append(line)
        while len(Buffer) > BufLen: del Buffer[0]
      # for
      # we don't really need the following lines:
      if args.lines >= 0: del Buffer[args.lines:]
    else: # start skipping lines
      BufLen = args.lines
      if args.startline > 1:
        nLeft = args.startline - 1
        for line in File:
          nLeft -= 1
          if nLeft <= 0: break
      for line in File:
        if BufLen >= 0 and len(Buffer) >= BufLen: break
        Buffer.append(line)
      # for
    # if
    
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
  
  
  sys.exit(0)
# main
