#!/usr/bin/env python
#
# Interfaces with okular
#

__version__ = "0.2"

import sys
import os
import optparse
import dbus
import time


def FormatSeconds(s):
	# TODO!
	
	if s > 60:
		m = int(s / 60.)
		s -= m * 60.
		if m >= 60.:
			h = m / 60
			m -= h * 60
			return "%dh %02d' %02.2f\"" % (h, m, s)
		else:
			return "%d' %02.2f\"" % (m, s)
	else:
		return "%.2f\"" % s
# FormatSeconds()


class Timer:
	def __init__(self, start=True):
		self.cumulate_time = 0.
		self.current_start = None
		if start: self.start()
		else:     self.stop()
	# __init__()
	
	def partial(self): return self.cumulate_time + self.last_session()
	
	def last_session(self):
		if not self.is_running(): return 0.
		else: return Timer.GetTime() - self.current_start
	# last_session()
	
	def start(self):
		elapsed = self.partial()
		self.cumulate_time = 0.
		self.current_start = Timer.GetTime()
		return elapsed
	# start()
	
	def stop(self):
		elapsed = self.partial()
		self.cumulate_time = 0.
		self.current_start = None
		return elapsed
	# stop()
	
	def is_running(self): return self.current_start is not None
	
	def pause(self):
		if self.is_running():
			self.cumulate_time += self.last_session()
			self.current_start = None
		return self.partial()
	# pause()
	
	def resume(self):
		if not self.is_running(): self.current_start = Timer.GetTime()
		return self.partial()
	# resume()
	
	def format_partial(self): return FormatSeconds(self.partial())
	
	def __call__(self): return self.partial()
	
	def __str__(self): return str(self.partial())
	
	@staticmethod
	def GetTime(): return time.time()
# class Timer


def Rehearse(args):
	
	# parameter parsing TODO
	OkularPID = int(args[1])
	if len(args) > 2:
		RequestedDocument = args[2]
		if not os.path.exists(RequestedDocument):
			raise RuntimeError \
			  ("The requested document %r doesn't exist!" % RequestedDocument)
		#
	else: RequestedDocument = None
	
	# connect to DBUS
	session_bus = dbus.SessionBus()
	if not session_bus:
		raise RuntimeError("Can't open DBUS session!")
	
	# get the Okular object and interface
	OkularObjectName = 'org.kde.okular-%d' % OkularPID
	OkularObject = session_bus.get_object(OkularObjectName, '/okular')
	if not OkularObject:
		raise RuntimeError("Can't contact Okular session '%s'" % OkularObjectName)
	
	OkularInterfaceName = 'org.kde.okular'
	Okular = dbus.Interface(OkularObject, dbus_interface=OkularInterfaceName)
	if not Okular:
		raise RuntimeError \
		  ("Can't obtain the interface %r of Okular" % OkularInterfaceName)
	# if
	
	# get information about the file being viewed
	DocumentName = str(Okular.currentDocument())
	
	if (RequestedDocument is not None) and (DocumentName != RequestedDocument):
		Okular.openDocument(RequestedDocument)
		DocumentName = str(Okular.currentDocument())
	#
	
	
	CurrentPage = int(Okular.currentPage())
	TotalPages = int(Okular.pages())
	
	print "Currently viewing %r, page %d/%d" \
	  % (DocumentName, CurrentPage, TotalPages)
	
	
	mode = "Startup"
	Timers = [ None ] * TotalPages
	try:
		while True:
			# pre-input
			if mode == "Startup":
				print "Press <Enter> to prepare..."
			elif mode == "GetReady":
				print "Press <Enter> to start! (then keep pressing <Enter>)"
			elif mode == "Rehearsal":
				CurrentTimer = None
				if CurrentPage <= len(Timers):
					CurrentTimer = Timers[CurrentPage - 1]
				if CurrentTimer is None:
					CurrentTimer = Timer(start=False)
					Timers[CurrentPage - 1] = CurrentTimer
				else:
					print "Page %d: %s so far" \
					  % (CurrentPage, CurrentTimer.format_partial())
				#
				CurrentTimer.resume()
				if CurrentPage == TotalPages:
					print "Press <Enter> to go to end the rehearsal"
			elif mode == "Review":
				pass
			elif mode == "RehearsalEnd":
				print "Document %s, %d pages:" % (DocumentName, TotalPages)
				Padding = len(str(TotalPages))
				NSlides = 0
				ElapsedTime = 0
				for iPage, PageTimer in enumerate(Timers):
					if PageTimer is None: continue # page skipped
					print "Page %*d: %s" \
					  % (Padding, iPage+1, PageTimer.format_partial())
					ElapsedTime += PageTimer.partial()
					NSlides += 1
				# for
				print "Time elapsed for %d slides: %s" \
				  % (NSlides, FormatSeconds(ElapsedTime))
				print "\nPress <Enter> to quit, type 'restart' to start over."
			else:
				raise NotImplementedError \
				  ("Don't know what to say in %r mode" % mode)
			#
			
			if (CurrentPage > 0) and (CurrentPage <= TotalPages):
				Okular.goToPage(CurrentPage)
			
			sys.stdout.write("> ")
			command = sys.stdin.readline().strip()
			
			if command == "quit": break
			
			# post-input
			if mode == "Startup":
				Okular.slotGotoFirst()
				CurrentPage = 0
				mode = "GetReady"
				continue
			elif mode == "GetReady":
				Timers = [ None ] * TotalPages
				print "Started!!"
				CurrentPage = 1
				mode = "Rehearsal"
			elif mode == "Rehearsal":
				if command == "help":
					print "Available commands (excluding 'help'):"
					print " stop : skip the rest of the slides, end the rehearsal"
					print " <Enter> : next slide!"
					continue
				# if help
				CurrentTimer.pause()
				print "Slide %d: %s" \
				  % (CurrentPage, CurrentTimer.format_partial())
				if command == "stop":
					mode = "RehearsalEnd"
					continue
				#
				try: 
					NewPage = int(command)
					if (NewPage > 0) and (NewPage <= TotalPages):
						CurrentPage = NewPage
				except:
					CurrentPage += 1
					if CurrentPage == TotalPages: mode = "RehearsalEnd"
			elif mode == "Review":
				if len(command) == 0: break
				if command == "restart":
					mode = "GetReady"
					continue
				# if
			elif mode == "RehearsalEnd":
				if len(command) == 0: break
				if command == "restart":
					mode = "GetReady"
					continue
				# if
				try: 
					NewPage = int(command)
					if (NewPage > 0) and (NewPage <= TotalPages):
						CurrentPage = NewPage
					mode == "Review"
				except: pass
				break
			else:
				raise NotImplementedError("Don't know what to do in %r mode" % mode)
			
		# while
	except KeyboardInterrupt: pass
	
	return 0
# Rehearse()


if __name__ == "__main__": sys.exit(Rehearse(sys.argv))