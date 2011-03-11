#
# event.pyx
#
# libevent Python bindings
#
# Copyright (c) 2004 Dug Song <dugsong@monkey.org>
# Copyright (c) 2003 Martin Murray <murrayma@citi.umich.edu>
#
# $Id: event.pyx 62 2010-03-08 14:35:41Z dugsong $

"""event library

This module provides a mechanism to execute a function when a
specific event on a file handle, file descriptor, or signal occurs,
or after a given time has passed.
"""

__author__ = ( 'Dug Song <dugsong@monkey.org>',
               'Martin Murray <mmurray@monkey.org>',
               'Aaron Westendorf <aaron@agoragames.com>' )
__copyright__ = ( 'Copyright (c) 2004 Dug Song',
                  'Copyright (c) 2003 Martin Murray' )
__license__ = 'BSD'
__url__ = 'https://github.com/agoragames/pyevent'
__version__ = '0.4.1'

import sys

cdef extern from "sys/types.h":
    ctypedef unsigned char u_char

cdef extern from "Python.h":
    void   Py_INCREF(object o)
    void   Py_DECREF(object o)
    object PyString_FromStringAndSize(char *v, int len)
    object PyString_FromString(char *v)
    int    PyObject_AsCharBuffer(object obj, char **buffer, int *buffer_len)

ctypedef void (*event_handler)(int fd, short evtype, void *arg)
    
cdef extern from "event.h":
    struct timeval:
        unsigned int tv_sec
        unsigned int tv_usec
    
    struct event_t "event":
        int   ev_fd
        int   ev_flags
        void *ev_arg

    void event_init()
    void event_set(event_t *ev, int fd, short event,
                   event_handler handler, void *arg)
    void evtimer_set(event_t *ev, event_handler handler, void *arg)
    int  event_add(event_t *ev, timeval *tv)
    int  event_del(event_t *ev)
    int  event_dispatch() nogil
    int  event_loop(int loop) nogil
    int  event_loopbreak()
    int  event_pending(event_t *ev, short, timeval *tv)
    
    int EVLOOP_ONCE
    int EVLOOP_NONBLOCK

EV_TIMEOUT = 0x01
EV_READ    = 0x02
EV_WRITE   = 0x04
EV_SIGNAL  = 0x08
EV_PERSIST = 0x10

__event_exc = None

cdef void __event_abort():
    global __event_exc

    event_loopbreak()
    __event_exc = sys.exc_info()
    if __event_exc[0] is None:
        __event_exc = None

cdef void __event_handler(int fd, short evtype, void *arg) with gil:
    (<object>arg).__callback(evtype)

cdef void __simple_event_handler(int fd, short evtype, void *arg) with gil:
    (<object>arg).__simple_callback(evtype)

cdef class event:
    """event(callback, arg=None, evtype=0, handle=None) -> event object
    
    Create a new event object with a user callback.

    Arguments:

    callback -- user callback with (ev, handle, evtype, arg) prototype
    arg      -- optional callback arguments
    evtype   -- bitmask of EV_READ or EV_WRITE, or EV_SIGNAL
    handle   -- for EV_READ or EV_WRITE, a file handle, descriptor, or socket
                for EV_SIGNAL, a signal number
    """
    cdef event_t ev
    cdef object handle, evtype, callback, args
    cdef float timeout
    cdef timeval tv

    def __init__(self, callback, arg=None, short evtype=0, handle=-1,
                 simple=0):
        cdef event_handler handler
        
        self.callback = callback
        self.args = arg
        self.evtype = evtype
        self.handle = handle
        if simple:
            handler = __simple_event_handler
        else:
            handler = __event_handler
        if evtype == 0 and not handle:
            evtimer_set(&self.ev, handler, <void *>self)
        else:
            if not isinstance(handle, int):
                handle = handle.fileno()
            event_set(&self.ev, handle, evtype, handler, <void *>self)

    def __simple_callback(self, short evtype):
        try:
            if self.callback(*self.args) != None:
                if self.tv.tv_sec or self.tv.tv_usec:
                    event_add(&self.ev, &self.tv)
                else:
                    event_add(&self.ev, NULL)
        except:
            __event_abort()
        # XXX - account for event.signal() EV_PERSIST
        if not (evtype & EV_SIGNAL) and \
           not event_pending(&self.ev, EV_READ|EV_WRITE|EV_SIGNAL|EV_TIMEOUT, NULL):
            Py_DECREF(self)
    
    def __callback(self, short evtype):
        try:
            self.callback(self, self.handle, evtype, self.args)
        except:
            __event_abort()
        if not event_pending(&self.ev, EV_READ|EV_WRITE|EV_SIGNAL|EV_TIMEOUT, NULL):
            Py_DECREF(self)

    def add(self, float timeout=-1):
        """Add event to be executed after an optional timeout.

        Arguments:
        
        timeout -- seconds after which the event will be executed
        """
        if not event_pending(&self.ev, EV_READ|EV_WRITE|EV_SIGNAL|EV_TIMEOUT,
                             NULL):
            Py_INCREF(self)
        self.timeout = timeout
        if timeout >= 0.0:
            self.tv.tv_sec = <long>timeout
            self.tv.tv_usec = <unsigned int>((timeout - <float>self.tv.tv_sec) * 1000000.0)
            event_add(&self.ev, &self.tv)
        else:
            self.tv.tv_sec = self.tv.tv_usec = 0
            event_add(&self.ev, NULL)

    def pending(self):
        """Return 1 if the event is scheduled to run, or else 0."""
        return event_pending(&self.ev, EV_TIMEOUT|EV_SIGNAL|EV_READ|EV_WRITE, NULL)
    
    def delete(self):
        """Remove event from the event queue."""
        if self.pending():
            event_del(&self.ev)
            Py_DECREF(self)
    
    def __dealloc__(self):
        self.delete()
    
    def __repr__(self):
        return '<event flags=0x%x, handle=%s, callback=%s, arg=%s>' % \
               (self.ev.ev_flags, self.handle, self.callback, self.args)

def init():
    """Initialize event queue."""
    event_init()

def dispatch():
    """Dispatch all events on the event queue.
    Returns -1 on error, 0 on success, and 1 if no events are registered.
    """
    cdef int ret
    global __event_exc
    with nogil:
        ret = event_dispatch()
    if __event_exc:
        t = __event_exc
        __event_exc = None
        raise t[0], t[1], t[2]
    return ret

def loop(nonblock=False):
    """Dispatch all pending events on queue in a single pass.
    Returns -1 on error, 0 on success, and 1 if no events are registered."""
    cdef int flags, ret
    global __event_exc
    flags = EVLOOP_ONCE
    if nonblock:
        flags = EVLOOP_ONCE|EVLOOP_NONBLOCK
    with nogil:
        ret = event_loop(flags)
    if __event_exc:
        t = __event_exc
        __event_exc = None
        raise t[0], t[1], t[2]
    return ret

def abort():
    """Abort event dispatch loop."""
    __event_abort()

include "simple.pxi"

include "bufferevent.pxi"

include "evdns.pxi"

include "evhttp.pxi"

# XXX - make sure event queue is always initialized.
init()
