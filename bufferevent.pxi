
# bufferevent

cdef struct evbuffer
cdef struct bufev_t
    
cdef extern from "event.h":
    bufev_t *bufferevent_new(int fd, void (*readcb)(bufev_t *b, void *arg),
                             void (*writecb)(bufev_t *b, void *arg),
                             void (*errorcb)(bufev_t *b, short e, void *arg),
                             void *cbarg)
    void bufferevent_free(bufev_t *b)
    int bufferevent_write(bufev_t *b, void *data, int size)
    int bufferevent_read(bufev_t *b, void *data, int size)
    int bufferevent_enable(bufev_t *b, short event)
    int bufferevent_disable(bufev_t *b, short event)
    void bufferevent_settimeout(bufev_t *b, int read_secs, int write_secs)

EVBUFFER_READ     = 0x01
EVBUFFER_WRITE    = 0x02
EVBUFFER_EOF      = 0x10
EVBUFFER_ERROR    = 0x20
EVBUFFER_TIMEOUT  = 0x40
    
ctypedef void (*evbuffer_handler)(bufev_t *b, void *arg)
ctypedef void (*everror_handler)(bufev_t *b, short what, void *arg)

cdef void __bufev_readcb(bufev_t *b, void *arg) with gil:
    o = (<object>arg)
    o.readcb(*o.args)

cdef void __bufev_writecb(bufev_t *b, void *arg) with gil:
    o = (<object>arg)
    o.writecb(*o.args)

cdef void __bufev_errorcb(bufev_t *b, short what, void *arg) with gil:
    o = (<object>arg)
    o.errorcb(what, *o.args)

cdef class bufferevent:
    """bufferevent(handle, readcb, writecb, errorcb, *args) -> bufferevent object

    Create a new buffered event

    Arguments:

    handle   -- file handle, descriptor, or socket
    readcb   -- callback to invoke when there is data to be read, or None
    writecb  -- callback to invoke when ready for writing, or None
    errorcb  -- callback to invoke on error, or None
    *args    -- optional arguments to be passed to each of the callbacks
    """
    cdef bufev_t *bufev
    cdef public object handle, readcb, writecb, errorcb, args
    
    def __init__(self, handle, readcb, writecb, errorcb, *args):
        cdef evbuffer_handler rcb, wcb
        cdef everror_handler ecb
        
        self.handle = handle
        self.readcb = readcb
        self.writecb = writecb
        self.errorcb = errorcb
        self.args = args

        rcb = wcb = ecb = NULL
        
        if readcb is not None:
            rcb = __bufev_readcb
        if writecb is not None:
            wcb = __bufev_writecb
        if errorcb is not None:
            ecb  = __bufev_errorcb
            
        if not isinstance(handle, int):
            handle = handle.fileno()

        self.bufev = bufferevent_new(handle, rcb, wcb, ecb, <void *>self)
        
    def enable(self, short evtype):
        """Enable a bufferevent.

        Arguments:

        evtype  -- any combination of EV_READ | EV_WRITE
        """
        bufferevent_enable(self.bufev, evtype)

    def disable(self, short evtype):
        """Disable a bufferevent.

        Arguments:

        evtype  -- any combination of EV_READ | EV_WRITE
        """
        bufferevent_disable(self.bufev, evtype)

    def write(self, buf):
        """Write data to a bufferevent. The data is appended to the output
        buffer and written to the handle automatically as it becomes available
        for writing. Returns 0 if successful, or -1 on error.
        
        Arguments:

        buf  -- data to write
        """
        cdef char *p
        cdef int n

        if PyObject_AsCharBuffer(buf, &p, &n) < 0:
            raise TypeError
        return bufferevent_write(self.bufev, p, n)
    
    def set_timeout(self, int read_secs, int write_secs):
        bufferevent_settimeout(self.bufev, read_secs, write_secs)

    def __dealloc__(self):
        bufferevent_free(self.bufev)
    
    def __repr__(self):
        return '<bufferevent handle=%s, readcb=%s, writecb=%s, errorcb=%s, args=%s>' % (self.handle, self.readcb, self.writecb, self.errorcb, self.args)
    
