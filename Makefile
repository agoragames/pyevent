# $Id: Makefile 61 2010-03-08 14:34:59Z dugsong $

PYTHON ?= python
#PYTHON	= DISTUTILS_USE_SDK=1 MSSdk=1 python2.5
#CONFIG_ARGS = --with-libevent=$(HOME)/build/libevent-1.4.4

PYREXC ?= cython

PKGDIR	= pyevent-`egrep version setup.py | cut -f2 -d"'"`

all: event.c
	$(PYTHON) setup.py config $(CONFIG_ARGS)
	$(PYTHON) setup.py build

event.c: event.pyx bufferevent.pxi evdns.pxi evhttp.pxi simple.pxi
	$(PYREXC) event.pyx

install:
	$(PYTHON) setup.py install

test:
	$(PYTHON) test.py

doc:
	epydoc -o doc -n event -u http://monkey.org/~dugsong/pyevent/ --docformat=plaintext event

pkg_win32:
	$(PYTHON) setup.py bdist_wininst

pkg_osx:
	bdist_mpkg --readme=README --license=LICENSE
	mv dist $(PKGDIR)
	hdiutil create -srcfolder $(PKGDIR) $(PKGDIR).dmg
	mv $(PKGDIR) dist

clean:
	$(PYTHON) setup.py clean
	rm -rf build dist

cleandir distclean: clean
	$(PYTHON) setup.py clean -a
	rm -f *.c *~
