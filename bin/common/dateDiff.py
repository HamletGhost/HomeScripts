#!/usr/bin/env python


from datetime import datetime


__doc__ = """Prints the difference between two dates.

"""
__version__ = "1.0"

#-------------------------------------------------------------------------------
class DateReader:
  class EOFError(Exception): pass

  def __init__(self, stream, format_ = "%c"):
    self.stream = stream
    self.format_ = format_
  # def __init__()
  
  def __call__(self):
    """Returns a date extracted from a line in the stream.
    Raises ValueError if format is wrong.
    Raises EOFError if the stream is over.
    """
    dateString = self.stream.readline()
    if not dateString: raise EOFError
    return datetime.strptime(dateString.strip(), self.format_)
  # def readDate()
  
  def __iter__(self): return self
  def __next__(self):
    try:             return self()
    except EOFError: raise StopIteration
  
# class DateReader

#-------------------------------------------------------------------------------
def dateDiff(dateFrom, dateTo):
  return dateTo - dateFrom


#-------------------------------------------------------------------------------
class TimePeriodFormatter:
  def __init__(self, **options): pass
  
  def __call__(self, diff):
    return str(diff.days)
  
# class TimePeriodFormatter

#-------------------------------------------------------------------------------
if __name__ == "__main__":
  
  import sys
  import argparse
  import io
  
  parser = argparse.ArgumentParser(
    description=__doc__
    )
  
  parser.add_argument("Dates", nargs="*", action="store",
    help="dates to compare [default: from stdin]")
  parser.add_argument('--format', dest="dateFormat", action="store"
    , help="format of the date in input, as in strptime() [%(default)s]"
    , default='%c'
    )
  parser.add_argument('--version', action='version',
    version='%(prog)s v' + __version__)
  
  arguments = parser.parse_args()
  
  if len(arguments.Dates) == 1:
    raise RuntimeError("At least two dates must be specified.")
  
  printDateDiff = TimePeriodFormatter()
  
  inputStream \
    = io.StringIO("\n".join(arguments.Dates)) if arguments.Dates \
      else sys.stdin
  reader = DateReader(inputStream, format_=arguments.dateFormat)
  
  try: firstDate = reader()
  except DateReader.EOFError:
    raise RuntimeError("Couldn't read any date!")
    
  for nextDate in reader:
    print(printDateDiff(dateDiff(firstDate, nextDate)))
    firstDate = nextDate
  # for
  
  sys.exit(0)
# main

#-------------------------------------------------------------------------------
