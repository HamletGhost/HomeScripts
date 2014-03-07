#!/usr/bin/python
#

import sys
import math


def help(params = None):
	if params is None or len(params) == 0: params = sys.argv
	print """
Converts a measure to another unit.

Usage:  %s 
""" % params[0]
# help()


class Transform:
	def __init__(self, params = None):
		pass
	# Transform.__init__()
	
	def __call__(self, values):
		return self.transform_direct(values)
	
	def transform_direct(self, values):
		return values[0]
	
	def transform_inverse(self, values):
		return values[0]
	
# Transform

class LinearTransform(Transform):
	def __init__(self, params = None):
		if params is None: self.params = [ 0., 1. ]
		elif len(params) == 1: self.params = [ 0., params ]
		else self.params = params[0:2]
	# LinearTransform.__init__()
	
	def transform_direct(self, values):
		return values[0] * self.params[1] + self.params[0]
	# LinearTransform.transform_direct()
	
	def transform_inverse(self, values):
		return (self.params[1] - self.params[0]) / values[0]
	# LinearTransform.transform_inverse()
# LinearTransform


class Unit:
	"""Unit of maesurement."""
	
	# class constants follow
	SI_prefixes = {
		'a': 1e-18,
		'f': 1e-15,
		'p': 1e-12,
		'n': 1e-9,
		'u': 1e-6,
		'm': 1e-3,
		'c': 1e-2,
		'd': 1e-1,
		'':  1e0,
		'da': 1e1,
		'h': 1e2,
		'k': 1e3,
		'M': 1e6,
		'G': 1e9,
		'T': 1e12,
		'P': 1e15,
		'E': 1e18,
	} # SI_prefixes
	
	byte_prefixes = {
		'ki': 2 << 10,
		'Mi': 2 << 20,
		'Gi': 2 << 30,
		'Ti': 2 << 40,
		'Pi': 2 << 50,
		'Ei': 2 << 60,
	} # byte_prefixes
	prefixes = {}
	prefixes.update(SI_prefixes)
	prefixes.update(byte_prefixes)
	
	def __init__(self, s = None):
		self.category = None
		self.unit = None
		self.prefix = None
		if s is not None: self.read(s)
	# Unit.__init__()
	
	def assign_category(self, categories = None):
		self.category = None
		if categories is not None:
			for catname, category in categories.items():
				if category.hasUnit(symbol=self.unit):
					self.category = catname
					break
	# Unit.assign_category()
	
	def read(self, s):
		self.prefix = None
		for prefix in prefixes:
			if s.startswith(prefix) and len(prefix)
		if self.prefix is None: self.prefix = '' # never if '' prefix is included
		self.unit = s[len(self.prefix):]
		self.assign_category()
	# Unit.read()
	
# class Unit


def UnitCategory:
	def __init__(self, name, defunitname, defunitsymbol):
		self.name = name
		self.units = {}
		self.defunit = None
		self.RegisterUnit(defunitname, defunitsymbol, None)
		self.defunit = defunitname
		# caches
		self.symbols = []
		self.InverseConvMap = {}
	# __init__()
	
	def RegisterUnit(self, name, symbol, transform, tounit = None):
		"""Register a new unit and its transformation to another."""
		
		# check about tounit definition; it will fall to None when called by init
		if tounit is not None:
			if not self.units.has_key(tounit):
				raise exceptions.run_time(
					"Unit '%s' not registered in category '%s'" % (tounit, self.name)
					)
		else: tounit = self.defunit
		
		res = 0
		if self.units.has_key(name):
			print >>sys.stderr, \
				"Warning: unit '%s' already registered in category '%s'" \
				% (name, self.name)
			res = 1
		self.units[name] = { 'name': name, 'symbol': symbol,
			'conv': { tounit: transform }, }
		# update caches
		if symbol not in self.symbols: self.symbols.append(symbol)
		self.RebuildInverseConv()
		return res
	# UnitCategory.RegisterUnit()
	
	def RebuildInverseConv(self):
		self.InverseConvMap = {}
		for fromunit in self.units.keys():
			for tounit, transform in self.units[fromunit]['conv'].items():
				if transform is not None and tounit != fromunit:
					if not self.InverseConvMap.has_key(tounit):
						self.InverseConvMap[tounit] = []
					self.InverseConvMap[tounit].append(fromunit)
			# for tounit
		# for fromunit
	# UnitCategory.RebuildInverseConv()
	
	def hasUnit(self, name=None, symbol=None):
		if name is not None:
			if not self.units.has_key(name): return False
			if symbol is not None and self.units[name]['symbol'] != symbol:
				return False
		elif symbol is not None:
			return symbol in self.symbols
		else: return False
	# UnitCategory.hasUnit()
	
	def convert(self, value, fromunit, tounit):
		FromUnit = Unit(fromunit)
		if not self.hasUnit(symbol=FromUnit.symbol): return None
		ToUnit = Unit(tounit)
		if not self.hasUnit(symbol=ToUnit.symbol): return None
		
		transform = None
		# try direct transformation first
		if transform is None:
			self.units[FromUnit]['conv'].has_key(ToUnit.):
				transform = 
		
	# convert()
	
# class UnitCategory


### main #######################################################################
if __name__ == "__main__":
	
	### parameters check
	for key in [ '-h', '--help', '-?' ]:
		if key in sys.argv:
			help()
			sys.exit(0)
	# help check
	if len(sys.argv) <= 2:
		help()
		sys.exit(1)
	
	value = sys.argv[1]
	unit = sys.argv[2]
	
	tounit = None
	if len(sys.argv) > 3: tounit = sys.argv[3]
	
	
	
	
	sys.exit(0)
# main
