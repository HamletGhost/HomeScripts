#!/usr/bin/python
# -*- coding: iso-8859-1 -*-

import sys
import math

class PrimeStorage:
	def __init__(self, n = None):
		self.store = [ 2, 3 ]
		if n is not None: self.Store(n)
	# __init__()
	
	def isPrime(self, n):
		max_d = int(math.sqrt(n))
		self.Store(max_d)
		for d in self.store:
			if n % d == 0: return False
		else: return True
	# isPrime()

	def Store(self, n):
		for d in xrange(self.store[-1] + 2, n+1, 2):
			if not self.isPrime(d): continue
			if n % d != 0: self.store.append(d)
		# for
	# StorePrimes()
	
	def __get__(self, n):
		while len(self.store) <= n:
			self.Store(self.store[-1] + 4 * (n - self.store[-1]))
		return self.store[n]
	# __get__()
	
	def __contains__(self, n):
		if self.store[-1] < n: self.Store(n)
		return n in self.store
	# __contains__()
	
	def __iter__(self): return iter(self.store)
	def __str__(self): return str(self.store)
	def __repr__(self): return repr(self.store)
	
# PrimeStorage


PrimeNumbers = PrimeStorage()


def Decompose(n, store = None):
	if store is None: store = PrimeStorage()
	store.Store(n+1)
	remember_n = n
	factors = []
	for d in store:
		times = 0
		while n % d == 0:
			times += 1
			n /= d
		if times > 0:
			factors.append((d, times))
			if n == 1: break
	# for
	assert n == 1 or n == remember_n
	if len(factors) > 0: return factors
	else: return [ (remember_n, 1) ]
# Decompose()



def main(argv):
	for param in argv[1:]:
		try: n = int(param)
		except: return 1
		if n <= 0:
			print >>sys.stderr, "%d is not positive enough." % n
			continue
		factors = Decompose(n, PrimeNumbers)
		print "%d:" % n,
		for f, p in factors:
			if p == 1: print " %d" % f,
			else:      print " %d^%d" % (f, p),
		print
	# for
	return 0
# main()


if __name__ == "__main__":
	sys.exit(main(sys.argv))
