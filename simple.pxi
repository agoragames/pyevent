
cdef class read(event):
    """read(handle, callback, *args) -> event object
    
    Simplified event interface:
    Create a new read event, and add it to the event queue.
    
    Arguments:

    handle   -- file handle, descriptor, or socket
    callback -- user callback with (*args) prototype, which can return
                a non-None value to be rescheduled
    *args    -- optional callback arguments
    """
    def __init__(self, handle, callback, *args):
        event.__init__(self, callback, args, EV_READ, handle, simple=1)
        self.args = args	# XXX - incref
        self.add()

cdef class write(event):
    """write(handle, callback, *args) -> event object

    Simplified event interface:
    Create a new write event, and add it to the event queue.
    
    Arguments:

    handle   -- file handle, descriptor, or socket
    callback -- user callback with (*args) prototype, which can return
                a non-None value to be rescheduled
    *args    -- optional callback arguments
    """
    def __init__(self, handle, callback, *args):
        event.__init__(self, callback, args, EV_WRITE, handle, simple=1)
        self.args = args	# XXX - incref
        self.add()
        
cdef class signal(event):
    """signal(sig, callback, *args) -> event object

    Simplified event interface:
    Create a new signal event, and add it to the event queue.
    XXX - persistent event is added with EV_PERSIST, like signal_set()
    
    Arguments:

    sig      -- signal number
    callback -- user callback with (*args) prototype, which can return
                a non-None value to be rescheduled
    *args    -- optional callback arguments
    """
    def __init__(self, sig, callback, *args):
        event.__init__(self, callback, args, EV_SIGNAL|EV_PERSIST,
                       sig, simple=1)
        self.args = args	# XXX - incref
        self.add()

cdef class timeout(event):
    """timeout(secs, callback, *args) -> event object

    Simplified event interface:
    Create a new timer event, and add it to the event queue.

    Arguments:

    secs     -- event timeout in seconds
    callback -- user callback with (*args) prototype, which can return
                a non-None value to be rescheduled
    *args    -- optional callback arguments
    """
    def __init__(self, secs, callback, *args):
        event.__init__(self, callback, args, simple=1)
        self.args = args	# XXX - incref
        self.add(secs)

