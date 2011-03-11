# $Id: evhttp.pxi 58 2009-03-07 21:27:13Z dugsong $

cdef extern from "event.h":
    evbuffer *evbuffer_new()
    int       evbuffer_add(evbuffer *buf, char *p, int len)
    char     *evbuffer_readline(evbuffer *buf)
    void      evbuffer_free(evbuffer *buf)
    
    char     *EVBUFFER_DATA(evbuffer *buf)
    int	      EVBUFFER_LENGTH(evbuffer *buf)

HTTP_OK			= 200
HTTP_NOCONTENT		= 204
HTTP_MOVEPERM		= 301
HTTP_MOVETEMP		= 302
HTTP_NOTMODIFIED	= 304
HTTP_BADREQUEST		= 400
HTTP_NOTFOUND		= 404
HTTP_SERVUNAVAIL	= 503

EVHTTP_REQUEST		= 0
EVHTTP_RESPONSE		= 1

EVHTTP_REQ_GET		= 0
EVHTTP_REQ_POST		= 1
EVHTTP_REQ_HEAD		= 2

HTTP_method2name = { 0: 'GET', 1: 'POST', 2: 'HEAD' }
HTTP_name2method = { 'GET': 0, 'POST': 1, 'HEAD': 2 }

cdef extern from "evhttp.h":
    struct evhttp_t "evhttp":
        pass
    struct evkeyvalq:
        pass
    struct evhttp_request:
        evkeyvalq *input_headers
        evkeyvalq *output_headers
        char	*remote_host
        short	remote_port
        int	kind
        int	type
        char	*uri
        char	major
        char	minor
        evbuffer *input_buffer
    struct conn_t "evhttp_connection":
        pass

    # headers
    int       evhttp_add_header(evkeyvalq *q, char *name, char *val)
    char     *evhttp_find_header(evkeyvalq *q, char *name)

    # evhttp
    ctypedef void (*evhttp_handler)(evhttp_request *, void *arg)

    evhttp_t *evhttp_start(char *address, unsigned short port)
    void      evhttp_set_cb(evhttp_t *http, char *uri,
                           evhttp_handler handler, void *arg)
    void      evhttp_set_gencb(evhttp_t *http,
                           evhttp_handler handler, void *arg)
    void      evhttp_del_cb(evhttp_t *http, char *uri)
    void      evhttp_send_reply_start(evhttp_request *req,
                                      int status, char *reason)
    void      evhttp_send_reply_chunk(evhttp_request *req, evbuffer *buf)
    void      evhttp_send_reply_end(evhttp_request *req)
    void      evhttp_free(evhttp_t *http)

    # request
    ctypedef void (*evhttp_request_cb)(evhttp_request *r, void *arg)

    evhttp_request *evhttp_request_new(evhttp_request_cb reqcb, void *arg)
    void            evhttp_request_free(evhttp_request *r)
    
    # connection
    ctypedef void (*conn_closecb)(conn_t *c, void *arg)
    
    conn_t   *evhttp_connection_new(char *addr, short port)
    void      evhttp_connection_free(conn_t *c)
    void      evhttp_connection_set_local_address(conn_t *c, char *addr)
    void      evhttp_connection_set_timeout(conn_t *c, int secs)
    void      evhttp_connection_set_retries(conn_t *c, int retry_max)
    void      evhttp_connection_set_closecb(conn_t *c, conn_closecb closecb,
                                            void *arg)

    int       evhttp_make_request(conn_t *c, evhttp_request *req,
                                  int cmd_type, char *uri)

cdef class __start_response:
    cdef evhttp_request *req
    cdef int headers_sent
    cdef object code, reason
    
    def __init__(self):
        self.headers_sent = 0
        self.code = self.reason = None

    cdef void _set_req(self, evhttp_request *req):
        self.req = req
    
    def __call__(self, status, headers, exc_info=None):
        if exc_info is not None:
            try:
                if self.headers_sent != 0:
                    # Re-raise original exception if headers sent
                    raise exc_info[0], exc_info[1], exc_info[2]
            finally:
                exc_info = None
        elif self.code is not None:
            raise AssertionError("Headers already set!")

        self.code, self.reason = status.split(None, 1)
        for name, val in headers:
            evhttp_add_header(self.req.output_headers, name, val)
        return self.write

    def _check_headers_sent(self):
        # Only start sending response after we've gotten data to write
        if self.headers_sent == 0:
            evhttp_send_reply_start(self.req, int(self.code), self.reason)
            self.headers_sent = 1
    
    def write(self, data):
        cdef evbuffer *buf

        buf = evbuffer_new()
        evbuffer_add(buf, data, len(data))
        self._check_headers_sent()
        evhttp_send_reply_chunk(self.req, buf)
        evbuffer_free(buf)

    def end(self):
        self._check_headers_sent()
        evhttp_send_reply_end(self.req)

cdef class __wsgi_input:
    cdef evbuffer *_buf

    cdef void _set_buf(self, evbuffer *buf):
        self._buf = buf

    def read(self, size=-1):
        return PyString_FromStringAndSize(EVBUFFER_DATA(self._buf),
                                          EVBUFFER_LENGTH(self._buf))
    def readline(self):
        return evbuffer_readline(self._buf) or ''

    def readlines(self, hint=-1):
        return self.read().splitlines(1)

cdef void __path_handler(evhttp_request *req, void *arg) with gil:
    cdef __start_response start_response
    cdef __wsgi_input wsgi_input
    cdef char *content_type, *content_len, *host

    app = (<object>arg)
    if app is None:
        return
    start_response = __start_response()
    start_response._set_req(req)
    wsgi_input = __wsgi_input()
    wsgi_input._set_buf(req.input_buffer)
    content_type = evhttp_find_header(req.input_headers, 'Content-Type')
    if not content_type: content_type = ''
    content_len = evhttp_find_header(req.input_headers, 'Content-Length')
    if not content_len: content_len = ''
    host = evhttp_find_header(req.input_headers, 'Host')
    if not host:
        server_name = ''
        server_port = '80'
    else:
        l = host.split(':')
        server_name = l[0]
        if len(l) > 1:
            server_port = l[1]
        else:
            server_port = '80'
    environ = {
        # WSGI/1.0
        'wsgi.version': (1,0),
        'wsgi.url_scheme': 'http',
        'wsgi.input': wsgi_input,
        'wsgi.errors': sys.stderr,
        'wsgi.multithread': False,
        'wsgi.multiprocess': False,
        'wsgi.run_once': False,
        # CGI/1.1
        'REQUEST_METHOD': HTTP_method2name[req.type],
        'SCRIPT_NAME': req.uri,
        'PATH_INFO': '',
        'QUERY_STRING':'',
        'CONTENT_TYPE': content_type,
        'CONTENT_LENGTH': content_len,
        'SERVER_NAME': server_name,
        'SERVER_PORT': server_port,
        'SERVER_PROTOCOL':'HTTP/%s.%s' % (req.major, req.minor),
        'REMOTE_HOST': req.remote_host, # XXX
        # Extras
        'REMOTE_ADDR': req.remote_host,
        'REMOTE_PORT': '%d' % req.remote_port,
        }
    for buf in app(environ, start_response):
        if buf:
            start_response.write(buf)
    start_response.end()

cdef class wsgi:
    """wsgi(address='0.0.0.0', port=80) -> WSGI server object

    Create a WSGI/1.0 application server object.

    Arguments:

    address -- IP address to bind to (defaults to any)
    port    -- port to listen on (defaults to 80)
    """
    cdef evhttp_t *_http
    
    def __init__(self, address='0.0.0.0', port=80):
        self._http = evhttp_start(address, port)
        if self._http == NULL:
            raise OSError, 'bind'	# XXX - libevent should event_warn
    
    def register_app(self, path, app):
        """Register a WSGI application

        Arguments:

        path -- URI path for the application to be bound to
        app  -- WSGI application object
        """
        evhttp_set_cb(self._http, path, __path_handler, <void *>app)

    def register_default_app(self, app):
        """Register a default WSGI application

        Arguments:

        app  -- WSGI application object
        """
        evhttp_set_gencb(self._http, __path_handler, <void *>app)

    def unregister_app(self, path):
        """Unregister a WSGI application

        Arguments:

        path -- URI path of bound WSGI application
        """
        evhttp_del_cb(self._http, path)

    def run(self):
        """Run WSGI server."""
        import signal as _signal
        signal(_signal.SIGINT, abort)
        signal(_signal.SIGTERM, abort)
        dispatch()
    
    def __dealloc__(self):
        if self._http != NULL:
            evhttp_free(self._http)
        self._http = NULL

