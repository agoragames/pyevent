#!/usr/bin/env python
#
# $Id: setup.py 49 2008-05-11 03:06:12Z dugsong $

from distutils.core import setup, Extension
import glob, os, sys

# Give preference to libevent stored where python is, such as virtual environments
if glob.glob('%s/lib/libevent.*' % sys.prefix):
  print 'found installed libevent in', sys.prefix
  event = Extension(name='event',
                     sources=[ 'event.c' ],
                     include_dirs=[ '%s/include' % sys.prefix ],
                     library_dirs=[ '%s/lib' % sys.prefix ],
                     libraries=[ 'event' ])

# Give preference to local libevent
elif glob.glob('/usr/local/lib/libevent.*'):
  print 'found installed libevent in /usr/local/lib'
  event = Extension(name='event',
                     sources=[ 'event.c' ],
                     include_dirs=[ '/usr/local/include' ],
                     library_dirs=[ '/usr/local/lib' ],
                     libraries=[ 'event' ])

# Look for system libevent
elif glob.glob('/usr/lib/libevent.*'):
  print 'found system libevent for', sys.platform
  event = Extension(name='event',
                     sources=[ 'event.c' ],
                     libraries=[ 'event' ],
                     include_dirs=['/usr/include'],
                     library_dirs=['usr/lib'])


else:
    ev_dir = None
    l = glob.glob('../libevent*')
    l.reverse()
    for dir in l:
        if os.path.isdir(dir):
            ev_dir = dir
            break
    if not ev_dir:
        raise "couldn't find libevent installation or build directory"
    
    print 'found libevent build directory', ev_dir
    ev_srcs = [ 'event.c' ]
    ev_incdirs = [ ev_dir ]
    ev_extargs = []
    ev_extobjs = []
    ev_libraries = []
    
    if sys.platform == 'win32':
        ev_incdirs.extend([ '%s/WIN32-Code' % ev_dir,
                            '%s/compat' % ev_dir ])
        ev_srcs.extend([ '%s/%s' % (ev_dir, x) for x in [
            'WIN32-Code/misc.c', 'WIN32-Code/win32.c',
            'log.c', 'event.c' ]])
        ev_extargs = [ '-DWIN32', '-DHAVE_CONFIG_H' ]
        ev_libraries = [ 'wsock32' ]
    else:
        ev_extobjs = glob.glob('%s/*.o' % dir)

    event = Extension(name='event',
                      sources=ev_srcs,
                      include_dirs=ev_incdirs,
                      extra_compile_args=ev_extargs,
                      extra_objects=ev_extobjs,
                      libraries=ev_libraries)

setup(name='event-agora',
      version='0.4.1',
      author='Dug Song, Aaron Westendorf',
      author_email='dugsong@monkey.org, aaron@agoragames.com',
      url='https://github.com/agoragames/pyevent',
      description='event library',
      long_description="""This module provides a mechanism to execute a function when a specific event on a file handle, file descriptor, or signal occurs, or after a given time has passed.""",
      license='BSD',
      download_url='https://github.com/agoragames/pyevent',
      ext_modules = [ event ])
