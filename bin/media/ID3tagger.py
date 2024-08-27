#!/usr/bin/env python3
#
# Prepares a script tagging audio files.
# 
# Very primitive error handling here. Sorry.
#
# Changes:
# [v1.0]
#   original version
# 20170408 [v1.1]
#   added --genres option
# 20170408 [v1.2]
#   python 3; changed format of --genres
# 20170408 [v1.3]
#   added --pause option
# 20240605 [v1.4]
#   added pattern-based parsing and renaming
#

__doc__ = """Creates a script assigning ID3 tags to MP3 files.

The input file is interpreted as a sequence of "key: value" pairs.
Lines starting with a "#" are interpreted as comments.
The valid keys are:
- file (mandatory): the file to change
- album, artist (also: author), genre, year (also: date), title: standard ID3
    keys
- track (also: trackno): standard ID3 key, with value in the form of a single
    number representing the track number, or two numbers "#/#", where the
    second one represents the total number of tracks
- filepattern: assigns patterns from the file name
- titlepattern: assigns patterns from the title
- rename (also: newname): changes the name of the file to the specified name
  (replacing tags)
- any other key is added in the "comments" ID3 tag

Track number and total number are always assigned. If they are not specified,
they are computed automatically from the position in the list and the total
number of entries in the list, respectively.

Finally, if a name is not in the form "key: value", it is considered to be the
file name (that is, the "file:" key is to be considered optional).

The file path element must be the first one of the block of metadata pertaining
that file.

The file and title patterns are regular expressions applied to the file basename
(including suffix) and to the title string. Each time a pattern is specified but
does not match the string it's applied on, a warning is printed. Otherwise, tags
are defined: {f0}, {f1}, {f2}, etc. are the expression and all subexpressions
matching the file pattern, and likewise {t0}, {t1} etc. represent the
subexpressions matched by the title pattern.
The replacement is performed via `str.format()`.
Currently, only the rename field supports these tags.

The rename key will change the name of the underlying file to the one specified
by the rename value. The value is subject to tag replacement (see the paragraph
above). If the target name is already used by another file, the program will
immediately interrupt with an error.
"""
__version__ = "1.4"


import sys
import os
import os.path
import logging
import copy
import math
import re
import shlex


class EmptyObject: pass

class ID3GenresClass:
  
  Codes = {
      0: "Blues",
      1: "Classic Rock",
      2: "Country",
      3: "Dance",
      4: "Disco",
      5: "Funk",
      6: "Grunge",
      7: "Hip-Hop",
      8: "Jazz",
      9: "Metal",
     10: "New Age",
     11: "Oldies",
     12: "Other",
     13: "Pop",
     14: "R&B",
     15: "Rap",
     16: "Reggae",
     17: "Rock",
     18: "Techno",
     19: "Industrial",
     20: "Alternative",
     21: "Ska",
     22: "Death Metal",
     23: "Pranks",
     24: "Soundtrack",
     25: "Euro-Techno",
     26: "Ambient",
     27: "Trip-Hop",
     28: "Vocal",
     29: "Jazz+Funk",
     30: "Fusion",
     31: "Trance",
     32: "Classical",
     33: "Instrumental",
     34: "Acid",
     35: "House",
     36: "Game",
     37: "Sound Clip",
     38: "Gospel",
     39: "Noise",
     40: "AlternRock",
     41: "Bass",
     42: "Soul",
     43: "Punk",
     44: "Space",
     45: "Meditative",
     46: "Instrumental Pop",
     47: "Instrumental Rock",
     48: "Ethnic",
     49: "Gothic",
     50: "Darkwave",
     51: "Techno-Industrial",
     52: "Electronic",
     53: "Pop-Folk",
     54: "Eurodance",
     55: "Dream",
     56: "Southern Rock",
     57: "Comedy",
     58: "Cult",
     59: "Gangsta",
     60: "Top 40",
     61: "Christian Rap",
     62: "Pop/Funk",
     63: "Jungle",
     64: "Native American",
     65: "Cabaret",
     66: "New Wave",
     67: "Psychadelic",
     68: "Rave",
     69: "Showtunes",
     70: "Trailer",
     71: "Lo-Fi",
     72: "Tribal",
     73: "Acid Punk",
     74: "Acid Jazz",
     75: "Polka",
     76: "Retro",
     77: "Musical",
     78: "Rock & Roll",
     79: "Hard Rock",
     80: "Folk",
     81: "Folk-Rock",
     82: "National Folk",
     83: "Swing",
     84: "Fast Fusion",
     85: "Bebob",
     86: "Latin",
     87: "Revival",
     88: "Celtic",
     89: "Bluegrass",
     90: "Avantgarde",
     91: "Gothic Rock",
     92: "Progressive Rock",
     93: "Psychedelic Rock",
     94: "Symphonic Rock",
     95: "Slow Rock",
     96: "Big Band",
     97: "Chorus",
     98: "Easy Listening",
     99: "Acoustic",
    100: "Humour",
    101: "Speech",
    102: "Chanson",
    103: "Opera",
    104: "Chamber Music",
    105: "Sonata",
    106: "Symphony",
    107: "Booty Bass",
    108: "Primus",
    109: "Porn Groove",
    110: "Satire",
    111: "Slow Jam",
    112: "Club",
    113: "Tango",
    114: "Samba",
    115: "Folklore",
    116: "Ballad",
    117: "Power Ballad",
    118: "Rhythmic Soul",
    119: "Freestyle",
    120: "Duet",
    121: "Punk Rock",
    122: "Drum Solo",
    123: "A capella",
    124: "Euro-House",
    125: "Dance Hall",
  } # Codes
  
  
  @staticmethod
  def Match(key, code_key, code_values):
    # try if key is an integer, that is a code ID
    if isinstance(key, int): return key == code_key
    
    # otherwise match the string(s)
    if isinstance(code_values, str): code_values = ( code_values, )
    for value in code_values:
      if value.lower() == key: return True
    else: return False
  # Match()
  
  @staticmethod
  def GenreID(key):
    try: key = int(key)
    except ValueError: key = str(key).lower()
    for code_key, code_value in ID3GenresClass.Codes.items():
      if ID3GenresClass.Match(key, code_key, code_value):
        return code_key
    return None
  # GenreID()
  
  @staticmethod
  def Genre(key):
    ID = ID3GenresClass.GenreID(key)
    if ID is None: return None
    return ID3GenresClass.Codes[ID]
  # Genre()
  
  @staticmethod
  def Print(out):
    print(
      "The following {} genres are supported:"
        .format(len(ID3GenresClass.Codes)),
      file=out
      )
    codePadding = len(str(max(ID3GenresClass.Codes.keys())))
    genrePadding = max(map(len, ID3GenresClass.Codes.values()))
    items = [
    #  "  {}  ({})".format(genreName, code, )
      "  {}".format(genreName, code, )
      for code, genreName in sorted(ID3GenresClass.Codes.items(), key=lambda p: p[1])
      ]
    itemLength = max(map(len, items))
    try: WindowWidth = os.get_terminal_size().columns
    except OSError: WindowWidth = 80
    columns = int(WindowWidth / itemLength)
    rows = int(math.ceil(len(items)/columns))
    for row in range(rows):
      for col in range(columns):
        iItem = col * rows + row
        if iItem >= len(items): break
        print("{0:<{1}}".format(items[iItem], itemLength), file=out, end='')
      print(file=out)
    # for

  # Print()

# class ID3GenresClass


class BashQuoterClass:
   
   NonSimpleWord = re.compile('[^a-zA-Z0-9._-]')
   
   @staticmethod
   def isSimpleWord(s): return BashQuoterClass.NonSimpleWord.search(s) is None
      
   @staticmethod
   def Quote(s): return shlex.quote(s)
   
   @staticmethod
   def QuoteList(l): return [ BashQuoterClass.Quote(s) for s in l ]
   
   @staticmethod
   def QuoteWords(*words): return BashQuoterClass.QuoteList(words)

# class BashQuoterClass


class ProcessorClass:
   def __init__(self, options = None):
      self.state = {
         'FilePattern': re.compile('.*'),
         'TitlePattern': re.compile('.*'),
      }
      self.output = []
      self.commentKeys = set()
      self.baseDirectory = ''
      self.pause = options.PauseTime if options else 0.0
   # __init__()
   
   def ParseFile(self, InputSpecs):
      
      try:
         fileName = InputSpecs.name
         self.baseDirectory = os.path.dirname(fileName)
      except AttributeError:
         self.baseDirectory = ''
      
      return self.Parse(InputSpecs)
      
   # ParseFile
   
   
   def Parse(self, InputSpecs):
      
      for iLine, spec in enumerate(InputSpecs):
         spec = spec.strip();
         
         # empty line
         if not spec: continue
         
         # support full line comments
         if spec.startswith('#'): continue
         
         # if no colon is found, then we assume it's the file path
         try:
            key, value = map(str.strip, spec.split(':', 1))
            key = key.lower()
         except ValueError:
            key = "file"
            value = spec
         #
         
         if key == "file":
            if 'InputFile' in self.state: self.OutputCurrent()
            self.state['InputFile'] = os.path.join(self.baseDirectory, value)
            continue
         # if file
         
         for keyword, labels in (
           ( 'Album', 'album' ),
           ( 'Artist', ( 'artist', 'author', ) ),
           ( 'Genre', 'genre' ),
           ( 'Year', ( 'year', 'date', ) ),
           ( 'Title', 'title' ),
           ( 'TrackNo', ( 'track', 'trackno' ) ),
           ( 'NTracks', ( 'ntracks', 'tracks' ) ),
           ( 'FilePattern', ( 'filepattern', ) ),
           ( 'TitlePattern', ( 'titlepattern', ) ),
           ( 'Rename', ( 'rename', 'newname' ) ),
           ):
            
            if isinstance(labels, str): labels = ( labels, )
            for label in labels:
               if key == label.lower(): break
            else: continue
            
            try:
               self.state[keyword] = re.compile(value) if keyword.endswith('Pattern') else value
            except re.error as e:
               raise RuntimeError(f"Error in the regular expression for '{keyword}'"
                 f"of '{self.state.get('InputFile', '<starting file>')}' ('{value}'): {e}") from e
            break
         else: # a comment?
            self.state.setdefault('Comments', []).append("%s:%s" % (key, value))
         # if ...
      # for
      
      if 'InputFile' in self.state: self.OutputCurrent()
      
   # Parse()
   
   def OutputCurrent(self):
      self.output.append(copy.deepcopy(self.state))
   # OutputCurrent()
   
   
   def ValidateComment(self, comment):
      key, value = comment.split(':', 1)
      self.commentKeys.add(key.lower())
      return key, value
   # ValidateComment()
   
   
   def ExtractTags(self, item) -> "a dictionary with all supported tags":
      patternTags = {}
      for PatternName, PatternTarget, TagPrefix in (
        ( 'FilePattern', 'InputFile', 'f' ),
        ( 'TitlePattern', 'Title', 't' ),
      ):
         pattern = item.get(PatternName, None)
         if not pattern: continue
         try: s = item[PatternTarget]
         except KeyError: continue
         match = pattern.search(s)
         if not match:
            logging.warning(
               "%s '%s' did not match the pattern '%s': tags '%s*' won't be available.",
               PatternTarget, s, PatternName, TagPrefix,
               )
            continue
         # if not match
         
         # add all indexed matches and also the named ones
         patternTags.update({ (TagPrefix + str(i)): match.group(i) for i in range(len(match.groups()) + 1) })
         patternTags[TagPrefix] = patternTags[TagPrefix + '0']
         patternTags.update(match.groupdict())
      # for patterns
      return patternTags
   # ExtractTags()
   
   
   def OutputElement(self, item, iElem, nElem):
      try:
         InputFile = item['InputFile']
      except KeyError:
         raise RuntimeError("No file specified for item %d!", iElem)
      
      tagValues = self.ExtractTags(item)
      
      cmds = []
      
      cmd = [ "id3v2" ]
      
      for key, option in (
        ( 'Album', '--album' ),
        ( 'Artist', '--artist' ),
        ( 'Year', '--year' ),
        ( 'Title', '--song' ),
        ):
         try:
            cmd.extend((option, item[key] ))
         except KeyError: pass
      # for
      
      Genre = item.get('Genre', None)
      if Genre:
         GenreName = ID3GenresClass.Genre(Genre)
         if not GenreName:
            logging.warning("Unknown genre for '%s': '%s'", InputFile, Genre)
         cmd.extend(('--genre', GenreName, ))
      # if
      
      iTrack = item.get('TrackNo', iElem + 1)
      try:
         iTrack, nTracks = map(int, iTrack.split('/', 1))
      except (ValueError, AttributeError, ):
         nTracks = item.get('NTracks', nElem)
      cmd.extend(( '--track', "%s/%s" % (str(iTrack), str(nTracks)), ))
      
      for comment in item.get('Comments', []):
         self.ValidateComment(comment)
         cmd.extend(( '--comment', comment, ))
      # for
      
      cmd.append(InputFile)
      cmds.append(BashQuoterClass.QuoteList(cmd))
      
      if 'Rename' in item:
         try:
            NewName = item['Rename'].format(**tagValues)
         except KeyError as e:
            logging.error(
               "Tag '%s' is not available; '%s' won't be renamed. Available patterns:\n%s",
               str(e), InputFile, "\n".join(f" - '{t}' ('{v}')" for t, v in tagValues.items()),
               )
         else:
            # attempt to overwrite is failure
            cmds.append(
               BashQuoterClass.QuoteWords
                 ( 'mv', '-v', '--update=none-fail', InputFile, NewName)
                 + [ '||', 'exit', '$?' ]
               )
      # if rename request
      
      return cmds
      
   # OutputElement()
   
   
   def Output(self, OutputFile):
      items = self.output
      nItems = len(items)
      Padding = len(str(nItems))
      PreviousAlbum = None
      for iItem, item in enumerate(items):
         Album = item.get('Album', PreviousAlbum)
         if Album != PreviousAlbum:
            PreviousAlbum = Album
            cmd = ( 'echo', "Tagging album: '{}'".format(Album), )
            print(" ".join(BashQuoterClass.QuoteList(cmd)), file=OutputFile)
         # if new album
         
         try:
            InputFile = item['InputFile']
         except KeyError:
            raise RuntimeError("No file specified for item %d!", iItem)
         if (iItem > 0) and (self.pause > 0.0):
            cmd = ( 'sleep', str(self.pause), )
            print(" ".join(cmd), file=OutputFile)
         # if
         
         cmd = (
           'echo',
           "[{0:0{2}d}/{1:0{2}d}] Processing '{3}'".format(iItem+1, nItems, Padding, InputFile)
         )
         print(" ".join(BashQuoterClass.QuoteList(cmd)), file=OutputFile)
         
         cmds = self.OutputElement(item, iItem, nItems)
         for cmd in cmds:
            print(" ".join(cmd), file=OutputFile)
         
      # for
      cmd = [ 'echo', "Done." ]
      
      self.output = []
      return nItems
   # Output()
   
# class ProcessorClass



def Process(InputFile, OutputFile, options):
   """Processes the input file"""
   
   Processor = ProcessorClass(options)
   
   Processor.ParseFile(InputFile)
   
   nCommands = Processor.Output(OutputFile)
   
   logging.info("%d comment types found: '%s'", len(Processor.commentKeys),
     "', '".join(Processor.commentKeys))
   
# def Process()



if __name__ == "__main__":
   
   import argparse
   
   parser = argparse.ArgumentParser(
      description=__doc__
      )
   
   parser.add_argument("InputFiles", nargs="*", action="store",
     help="input files [default: from stdin]")
   
   parser.add_argument("--output", action="store", dest="OutputFile",
     help="output file [default: stdout]", default=None)
   parser.add_argument('--genres', action='store_true', dest='ListGenres',
     help="List all supported genres")
   parser.add_argument('--pause', action='store', dest='PauseTime', type=float,
     help="waits for this number of seconds after each tagging [%(default]",
     default=0.0)
   parser.add_argument('--version', action='version',
     version='%(prog)s v' + __version__)
   
   arguments = parser.parse_args()
   
   if arguments.ListGenres:
     ID3GenresClass.Print(sys.stdout)
     sys.exit(0)
   # if list genres

   if not arguments.InputFiles: arguments.InputFiles = [ "" ]
   
   if arguments.OutputFile is None: OutputFile = sys.stdout
   else:                            OutputFile = open(arguments.OutputFile, 'a')
   
   for InputPath in arguments.InputFiles:
     if not InputPath: InputFile = sys.stdin
     else:             InputFile = open(InputPath, 'r')
     
     Process(InputFile, OutputFile, arguments)
     
   # for
   
   if OutputFile is not sys.stdout:
      print("Output written in '{}'".format(OutputFile.name))
      OutputFile.close()
   # if
   sys.exit(0)
# main
