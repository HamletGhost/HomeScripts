#!/usr/bin/env python3
#
# This parser is very, very silly.
#

import sys
import io


class LookAheadStream:
  def __init__(self, baseStream):
    self.stream = baseStream
    self.buffer = ""
  # __init__()
  
  def peek(self, n: "number of characters to peek" = 1):
    toRead = n - len(self.buffer)
    if toRead > 0:
      read = self.stream.read(toRead)
      if not read: raise EOFError()
      self.buffer += read
    return self.buffer
  # peek()
  
  def read(self, n: "number of characters to read" = 1):
    data = self.peek(n)
    self.buffer = self.buffer[n:]
    return data
  # read()
  
# class LookAheadStream


def wasteBlanks(stream):
  try:
    while stream.peek().isspace(): stream.read()
  except EOFError: pass
# wasteBlanks()


class OutputBuffer:
  def __init__(self, stream):
    self.stream = stream
    self.buffer = ""
    self.ignore = False
  # __init__()
  
  def flush(self):
    self.stream.write(self.buffer)
    self.buffer = ""
  # flush()
  
  def write(self, s):
    if not self.ignore: self.buffer += s
  
  def writeNow(self, s):
    self.write(s)
    self.flush()
  # writeNow()
  
  def lastWord(self):
    try: return self.buffer.rstrip().rsplit(None, 1)[-1]
    except IndexError: return ""
  # lastWord()
  def dropLastWord(self):
    words = self.buffer.rstrip().rsplit(None, 1)
    if len(words) <= 1: goodie = 0
    self.buffer = self.buffer[:goodie]
  # dropLastWord()
  def endsWithSpace(self): return self.buffer and self.buffer[-1].isspace()
  
  def deaf(self, deafness): self.ignore = deafness
  
# class OutputBuffer


class StupidTemplatePrinter:
  
  class MisalignedCodeError(RuntimeError): pass
  
  
  def __init__(self,
   indent: "indentation string" = "  ",
   allocators: "print allocators (std::allocator<>)" = True
   ):
    self.options = {
      'indentStr':  indent,
      'allocators': allocators,
    }
  # __init__()
  
  def format(self, inputStream, outputStream):
    indentStr = self.options['indentStr']
    indentLevel = 0
    ignoreLevelsAbove = None
    
    ignoreLevel = lambda level: ((ignoreLevelsAbove is not None) and ( level > ignoreLevelsAbove))
    
    output = OutputBuffer(outputStream)
    
    while True:
      try: c = inputStream.read()
      except EOFError: break
      
      if c == '\n':
        pass
      elif c.isspace():
        if not output.endsWithSpace(): output.write(c)
      elif c in [ '(', '{', '<', ]:
        if (c == '<') and (output.lastWord() == 'std::allocator'):
          ignoreLevelsAbove = indentLevel
          output.dropLastWord()
        indentLevel += 1
        output.deaf(ignoreLevel(indentLevel))
        output.write(c)
        output.writeNow('\n' + indentStr * indentLevel)
        wasteBlanks(inputStream)
      elif c == ',':
        output.write(c)
        output.writeNow('\n' + indentStr * indentLevel)
        wasteBlanks(inputStream)
      elif c in [ ')', '}', '>', ]:
        if indentLevel == 0:
          raise StupidTemplatePrinter.MisalignedCodeError()
        indentLevel -= 1
        if ignoreLevelsAbove == indentLevel: ignoreLevelsAbove = None
        output.flush()
        output.writeNow('\n' + indentStr * indentLevel)
        output.write(c)
        output.deaf(ignoreLevel(indentLevel))
      else:
        output.write(c)
      
    # while
    
    output.writeNow('\n')
    if indentLevel > 0:
      raise StupidTemplatePrinter.MisalignedCodeError()
  # format()
  
  
# class StupidTemplatePrinter



if __name__ == "__main__":
  
  import sys
  import argparse
  
  parser = argparse.ArgumentParser(
    description='Filter printing C++ template class names as nested.'
    )
  parser.add_argument('--indent', dest='indentStr', type=str, default="  ",
    help='string used for alignment ["%(default)s"]')
  parser.add_argument('--suppress-allocators', dest='NoAllocators',
    action='store_true', help='omits allocators from the template lists')

  args = parser.parse_args()
  
  printer = StupidTemplatePrinter(
    indent=args.indentStr,
    allocators=not args.NoAllocators
    )
  
  printer.format(LookAheadStream(sys.stdin), sys.stdout)

  sys.exit(0)
# main
